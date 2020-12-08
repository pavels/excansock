#ifndef EXCANSOCK_H
#define EXCANSOCK_H

#include <erl_nif.h>

typedef struct {
  int socket;
  int canfd;

  ErlNifMutex* write_mtx;
  ErlNifMutex* read_mtx;
  
} ResourceData;

typedef struct {
  ERL_NIF_TERM atom_ok;
  ERL_NIF_TERM atom_undefined;
  ERL_NIF_TERM atom_error;
  ERL_NIF_TERM atom_nil;
  ERL_NIF_TERM atom_eagain;
  ERL_NIF_TERM atom_can_frame;
  ERL_NIF_TERM atom_enofd;
} PrivData;

static ErlNifResourceType *excansock_rt;

static ERL_NIF_TERM excansock_open_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM excansock_close_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM excansock_recv_own_messages_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM excansock_set_loopback_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM excansock_set_filters_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM excansock_set_error_filter_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM send_try_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM recv_try_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);


static void excansock_rt_dtor(ErlNifEnv *env, ResourceData *obj);

static int load(ErlNifEnv* env, void** priv, ERL_NIF_TERM info);
static int reload(ErlNifEnv* env, void** priv, ERL_NIF_TERM info);
static int upgrade(ErlNifEnv* env, void** priv, void** old_priv, ERL_NIF_TERM info);
static void unload(ErlNifEnv* env, void* priv);

static ErlNifFunc nif_funcs[] = {
  {"excansock_open", 2, excansock_open_nif, 0},
  {"excansock_close", 1, excansock_close_nif, 0},
  {"excansock_recv_own_messages", 2, excansock_recv_own_messages_nif, 0},
  {"excansock_set_loopback", 2, excansock_set_loopback_nif, 0},
  {"excansock_set_filters", 2, excansock_set_filters_nif, 0},
  {"excansock_set_error_filter", 2, excansock_set_error_filter_nif, 0},
  {"excansock_send_try", 3, send_try_nif, 0},
  {"excansock_recv_try", 1, recv_try_nif, 0},
};

ERL_NIF_INIT(Elixir.Excansock.Nif, nif_funcs, &load, &reload, &upgrade, &unload)

#endif // EXCANSOCK_H
