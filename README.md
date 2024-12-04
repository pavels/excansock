# Excansock

[![Hex version](https://img.shields.io/hexpm/v/excansock.svg "Hex version")](https://hex.pm/packages/excansock)

Excansock is an Elixir library, that allows you to communicate using CAN bus through SocketCAN API. As SocketCAN is Linux specific, this project is useful only on Linux operating system.

## Example use

Start the Excansock GenServer:

```elixir
iex> {:ok, pid} = Excansock.start_link
{:ok, #PID<0.132.0>}
```

The GenServer doesn't open a socket automatically, so you need to tell it first to do so. The CAN network interface must be initialized and up.

```elixir
iex> Excansock.open(pid, "can0")
:ok
```

The process calling the `open` function is automatically registered as receiver for the CAN frames.

We can try to send some frame on the bus like so:

```elixir
iex> frame = %Excansock.CanFrame{ id: 1, data: <<1, 2, 3, 4>> }
%Excansock.CanFrame{data: <<1, 2, 3, 4>>, id: 1}

iex> Excansock.send(pid, frame)
:ok
```

To receive frame we should either call `receive` or implement appropriate callback if our receiving module is `gen_server`

```elixir
iex> receive do msg -> msg end
{:can_data_frame, %Excansock.CanFrame{data: <<1, 2, 3, 4>>, id: 1}}
```

### C compiler dependencies

Since this library includes C code, `make`, `gcc`, and Erlang header and
development libraries are required.

On Linux systems, this usually requires you to install the `build-essential` and
`erlang-dev` packages. For example:

```sh
sudo apt-get install build-essential erlang-dev
```

## `ENOBUFS` error

If you experience `ENOBUFS` error during transmission, it means `txqueuelen` parameter of can interface is se too low. 

You can set it higher by executing:

```
ip link set can0 txqueuelen 100
```

As a rule of thumb, the `txqueuelen` should be set to the number of simultaneously used CAN sockets in the system multiplied by 15.

More information about this problem can be found here: [SocketCAN and queueing disciplines: Final Report](https://rtime.felk.cvut.cz/can/socketcan-qdisc-final.pdf), chapter 3.4.


## Testing

Before running tests, you need to initialize virtual can interface `vcan0` (as `root` or using `sudo`)

Run in shell:
```
modprobe vcan
ip link add dev vcan0 type vcan
ip link set up vcan0
```

Than you can run:
```
mix test
```

For some tests you need real can bus and another device, which electively echoes received messages without reordering them. To run these tests, set `REAL_CAN_INTERFACE` environment variable to real interface name (such as `can0`) and run `mix test`.
