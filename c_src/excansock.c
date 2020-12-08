#include <erl_nif.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>

#include <string.h>

#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/types.h>

#include <linux/if.h>
#include <linux/can.h>
#include <linux/can/raw.h>

#include "excansock.h"

#define SET_NONBLOCKING(fd)  fcntl((fd), F_SETFL, fcntl((fd), F_GETFL, 0) | O_NONBLOCK)

static ERL_NIF_TERM excansock_open_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  PrivData* priv = enif_priv_data(env);
  ResourceData *resource_data;
  ERL_NIF_TERM res;

  ErlNifBinary dev_name;
  int canfd;

  if (argc != 2 || 
      !enif_inspect_iolist_as_binary(env, argv[0], &dev_name) ||      
      !enif_get_int(env, argv[1], &canfd) ||
      dev_name.size >= IFNAMSIZ)
      return enif_make_badarg(env);

  int socket_fd = 0;
  int dev_id = -1;
  int r = 0;
  
  if ((socket_fd = socket(PF_CAN, SOCK_RAW, CAN_RAW)) < 0)
    return enif_make_tuple2(env, priv->atom_error, socket_fd);

  char dev_name_str[IFNAMSIZ];
  memcpy(dev_name_str, (const char *)dev_name.data, dev_name.size);
  dev_name_str[dev_name.size] = '\0';
  dev_id = if_nametoindex(dev_name_str); 

  if (!dev_id) {
    printf("Device %s not found", dev_name_str);
    close(socket_fd);
    return enif_make_tuple2(env, priv->atom_error, enif_make_int(env, errno));
  }

  struct sockaddr_can addr;

  addr.can_family = AF_CAN;
  addr.can_ifindex = dev_id;

  if ((r = bind(socket_fd, (struct sockaddr *)&addr, sizeof(addr))) < 0) {    
    close(socket_fd);
    return enif_make_tuple2(env, priv->atom_error, enif_make_int(env, r));
  }

  if(canfd == 1 && setsockopt(socket_fd, SOL_CAN_RAW, CAN_RAW_FD_FRAMES, &canfd, sizeof(canfd)) < 0) {
    close(socket_fd);
    return enif_make_tuple2(env, priv->atom_error, priv->atom_enofd);
  }

  // Set minimum SO_SNDBUF, txqueuelen still needs to be set properly or 
  // write will return ENOBUFS instead EAGAIN when tx queue is full
  int sndbuf = 0;
  if ((r = setsockopt(socket_fd, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf))) < 0) {
    close(socket_fd);
    return enif_make_tuple2(env, priv->atom_error, r);
  }

  SET_NONBLOCKING(socket_fd);

  resource_data = enif_alloc_resource(excansock_rt, sizeof(ResourceData));
  resource_data->socket = socket_fd;
  resource_data->canfd = canfd;

  resource_data->write_mtx = enif_mutex_create("excansock.write");
  resource_data->read_mtx = enif_mutex_create("excansock.read");

  res = enif_make_resource(env, resource_data);
  enif_release_resource(resource_data);
  return enif_make_tuple2(env, priv->atom_ok, res);
}

static ERL_NIF_TERM excansock_close_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  PrivData* priv = enif_priv_data(env);
  ResourceData *resource_data;
  int r;

  if (argc != 1 || 
      !enif_get_resource(env, argv[0], excansock_rt, (void**)&resource_data) ||
      resource_data->socket < 0)
    return enif_make_badarg(env);

  r = close(resource_data->socket);
  if(r < 0)
    return enif_make_tuple2(env, priv->atom_error, enif_make_int(env, r));

  resource_data->socket = -1;
  return priv->atom_ok;
}

static ERL_NIF_TERM excansock_recv_own_messages_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  PrivData* priv = enif_priv_data(env);
  ResourceData *resource_data;
  int val, r;

  if (argc != 2 || 
      !enif_get_resource(env, argv[0], excansock_rt, (void**)&resource_data) || 
      !enif_get_int(env, argv[1], &val))
    return enif_make_badarg(env);

  r = setsockopt(resource_data->socket, SOL_CAN_RAW, CAN_RAW_RECV_OWN_MSGS, &val, sizeof(val));
  if(r < 0)
    return enif_make_tuple2(env, priv->atom_error, enif_make_int(env, r));

  return priv->atom_ok;
}

static ERL_NIF_TERM excansock_set_loopback_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  PrivData* priv = enif_priv_data(env);
  ResourceData *resource_data;
  int val, r;

  if (argc != 2 || 
      !enif_get_resource(env, argv[0], excansock_rt, (void**)&resource_data) || 
      !enif_get_int(env, argv[1], &val))
    return enif_make_badarg(env);

  r = setsockopt(resource_data->socket, SOL_CAN_RAW, CAN_RAW_LOOPBACK, &val, sizeof(val));
  if(r < 0)
    return enif_make_tuple2(env, priv->atom_error, enif_make_int(env, r));

  return priv->atom_ok;
}

static ERL_NIF_TERM excansock_set_filters_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  PrivData* priv = enif_priv_data(env);
  ResourceData *resource_data;
  int r, i;
  struct can_filter* rfilter;

  unsigned int numfilter;

  ERL_NIF_TERM res;

  if (argc != 2 || 
      !enif_get_resource(env, argv[0], excansock_rt, (void**)&resource_data) || 
      !enif_get_list_length(env, argv[1], &numfilter))
    return enif_make_badarg(env);

  rfilter = malloc(sizeof(struct can_filter) * numfilter);

  ERL_NIF_TERM item, items;
  items = argv[1];
  i = 0;
  while(enif_get_list_cell(env, items, &item, &items)) {
    const ERL_NIF_TERM *filter;
    int arity;
    if (!enif_get_tuple(env, item, &arity, &filter) ||
        arity != 2 ||
        !enif_get_uint(env, filter[0], &(rfilter[i].can_id)) ||
        !enif_get_uint(env, filter[1], &(rfilter[i].can_mask))) {
      res = enif_make_badarg(env);
      goto done;
    }
   
    i++;
  }

  r = setsockopt(resource_data->socket, SOL_CAN_RAW, CAN_RAW_FILTER, rfilter, numfilter * sizeof(struct can_filter));
  if(r < 0) {    
    res = enif_make_tuple2(env, priv->atom_error, enif_make_int(env, r));
    goto done;
  }

  res = priv->atom_ok;

done:
  free(rfilter);
  return res;
}

static ERL_NIF_TERM excansock_set_error_filter_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  PrivData* priv = enif_priv_data(env);
  ResourceData *resource_data;
  int r;
  can_err_mask_t val;

  if (argc != 2 || 
      !enif_get_resource(env, argv[0], excansock_rt, (void**)&resource_data) || 
      !enif_get_uint(env, argv[1], &val))
    return enif_make_badarg(env);

  r = setsockopt(resource_data->socket, SOL_CAN_RAW, CAN_RAW_ERR_FILTER, &val, sizeof(val));
  if(r < 0)
    return enif_make_tuple2(env, priv->atom_error, enif_make_int(env, r));

  return priv->atom_ok;
}

static ERL_NIF_TERM send_try_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  PrivData* priv = enif_priv_data(env);
  ErlNifBinary data;
  ERL_NIF_TERM res;
  ResourceData *resource_data;
  
  int r;
  unsigned int can_id;

  if (argc != 3 ||
      !enif_get_resource(env, argv[0], excansock_rt, (void**)&resource_data) ||
      !enif_get_uint(env,argv[1],&can_id) ||
      !enif_inspect_iolist_as_binary(env,argv[2],&data) ||
      (resource_data->canfd == 0 && data.size > CAN_MAX_DLEN) ||
      (resource_data->canfd == 1 && data.size > CANFD_MAX_DLEN))
    return enif_make_badarg(env);

  enif_mutex_lock(resource_data->write_mtx);

  if(data.size > CAN_MAX_DLEN) {
    struct canfd_frame frame;
    frame.can_id = can_id;
    frame.len = data.size;
    memcpy(frame.data, data.data, data.size);
    r = write(resource_data->socket, &frame, sizeof(frame));
  } else {
    struct can_frame frame;
    frame.can_id = can_id;
    frame.can_dlc = data.size;
    memcpy(frame.data, data.data, data.size);
    r = write(resource_data->socket, &frame, sizeof(frame));
  }

  if (r < 0) {
    if (errno != EAGAIN && errno != EINTR) {
      res = enif_make_tuple2(env, priv->atom_error, enif_make_int(env,errno));
      goto done;
    }
  } else {
      res = priv->atom_ok;
      goto done;
  }

  r = enif_select(env, resource_data->socket, ERL_NIF_SELECT_WRITE, resource_data, NULL, priv->atom_undefined);
  if(r < 0) {
    res = enif_make_tuple2(env, priv->atom_error, enif_make_int(env, r));
    goto done;
  }

  res = priv->atom_eagain;

done:
  enif_mutex_unlock(resource_data->write_mtx);
  return res;
}

static ERL_NIF_TERM recv_try_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  PrivData* priv = enif_priv_data(env);
  ERL_NIF_TERM res;
  ResourceData *resource_data;
  ErlNifBinary read_bin;

  struct canfd_frame frame;
  int r;

  if (argc != 1 ||
      !enif_get_resource(env, argv[0], excansock_rt, (void**)&resource_data))
    return enif_make_badarg(env);

  enif_mutex_lock(resource_data->read_mtx);

  r = read(resource_data->socket, &frame, resource_data->canfd == 1 ? CANFD_MTU : CAN_MTU);

  if (r == CAN_MTU || r == CANFD_MTU) {
    enif_alloc_binary(frame.len, &read_bin);
    memcpy(read_bin.data, frame.data, frame.len);
    res = enif_make_tuple3(env, 
      priv->atom_can_frame, 
      enif_make_uint(env,frame.can_id),
      enif_make_binary(env,&read_bin)
    );
    goto done;
  } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
    res = enif_make_tuple2(env, priv->atom_error, enif_make_int(env,errno));
    goto done;
  }

  r = enif_select(env, resource_data->socket, ERL_NIF_SELECT_READ, resource_data, NULL, priv->atom_undefined);
  if(r < 0) {
    res = enif_make_tuple2(env, priv->atom_error, enif_make_int(env, r));
    goto done;
  }

  res = priv->atom_eagain;

done:
  enif_mutex_unlock(resource_data->read_mtx);
  return res;
}

/*
 * NIF Callbacks
 */

static void excansock_rt_dtor(ErlNifEnv *env, ResourceData *obj) {
  ResourceData* resource_data = (ResourceData*) obj;

  enif_mutex_destroy(resource_data->read_mtx);
  enif_mutex_destroy(resource_data->write_mtx);

  if(resource_data->socket > -1) {
    close(resource_data->socket);
  }
}

static int load(ErlNifEnv* env, void** priv, ERL_NIF_TERM info) {
  PrivData* data = enif_alloc(sizeof(PrivData));

  if (data == NULL) {
    return 1;
  }

  data->atom_ok = enif_make_atom(env, "ok");
  data->atom_undefined = enif_make_atom(env, "undefined");
  data->atom_error = enif_make_atom(env, "error");
  data->atom_eagain = enif_make_atom(env, "eagain");
  data->atom_can_frame = enif_make_atom(env, "can_frame");
  data->atom_enofd = enif_make_atom(env, "enofd");
  *priv = (void*) data;

  excansock_rt = enif_open_resource_type(env, NULL, "excansock_resource", (ErlNifResourceDtor*)excansock_rt_dtor, ERL_NIF_RT_CREATE, NULL);

  return !excansock_rt;
}

static int reload(ErlNifEnv* env, void** priv, ERL_NIF_TERM info) {
  return load(env, priv, info);
}

static int upgrade(ErlNifEnv* env, void** priv, void** old_priv, ERL_NIF_TERM info) {
  return load(env, priv, info);
}

static void unload(ErlNifEnv* env, void* priv) {
  enif_free(priv);
}