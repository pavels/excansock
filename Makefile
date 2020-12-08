# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

LDFLAGS += -shared

CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter
CFLAGS += -std=c99 -D_GNU_SOURCE -fPIC

OBJS = excansock.o
OBJS_P = $(addprefix $(BUILD)/,$(OBJS))

NIF=$(PREFIX)/excansock_nif.so

all: $(PREFIX) $(BUILD) $(NIF)

$(PREFIX) $(BUILD):
	mkdir -p $@

$(BUILD)/%.o : c_src/%.c
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(NIF): $(OBJS_P)
	$(CC) $(ERL_LDFLAGS) $(LDFLAGS) -o $@ $^

clean:
	$(RM) $(NIF)
