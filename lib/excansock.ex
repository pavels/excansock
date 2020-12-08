defmodule Excansock do
  use GenServer
  use Bitwise, only_operators: true

  import Excansock.CanConstants

  require Logger

  defmodule State do
    defstruct [
      socket: -1,
      controlling_process: nil,
      queue_size: 0,
      use_queue: false,
      queue: nil
    ]

    @type t() :: %__MODULE__{
      socket: number,
      controlling_process: pid | nil,
      queue_size: number,
      use_queue: boolean,
      queue: any
    }
  end

  defmodule CanFrame do
    @enforce_keys [:id, :data]
    defstruct [
      id: nil,
      data: <<>>
    ]

    @type t() :: %__MODULE__{
      id: number,
      data: binary
    }
  end

  defmodule CanFilter do
    @enforce_keys [:can_id, :can_mask]
    defstruct [
      can_id: 0,
      can_mask: 0
    ]

    @type t() :: %__MODULE__{
      can_id: number,
      can_mask: number
    }
  end

  @doc """
  Start up Excansock GenServer.
  """
  @spec start_link([term]) :: {:ok, pid} | {:error, term}
  def start_link(opts \\ []) do
    queue_size = Keyword.get(opts, :queue_size, 0)
    name = Keyword.get(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, {queue_size}, name: name)
  end


  @doc """
  Open CAN socket.
  """
  @spec open(GenServer.server(), binary, boolean) :: :ok | :error
  def open(pid, name, canfd \\ false) do
    GenServer.call(pid, {:open, name, canfd})
  end

  @doc """
  Close CAN socket.
  """
  @spec close(GenServer.server()) :: :ok | :error
  def close(pid) do
    GenServer.call(pid, :close)
  end

  @doc """
  Send CAN message
  """
  @spec send(GenServer.server(), CanFrame) :: :ok
  def send(pid, frame) do
    GenServer.call(pid, {:send, frame})
  end

  @doc """
  Enable / disable CAN loopback
  """
  @spec set_loopback(GenServer.server(), boolean) :: :ok
  def set_loopback(pid, value) do
    GenServer.call(pid, {:set_loopback, value})
  end

  @doc """
  Enable / disable receiving own messages
  """
  @spec recv_own_messages(GenServer.server(), boolean) :: :ok
  def recv_own_messages(pid, value) do
    GenServer.call(pid, {:recv_own_messages, value})
  end

  @doc """
  Set CAN filters
  """
  @spec set_filters(GenServer.server(), list(CanFilter.t)) :: :ok
  def set_filters(pid, filters) do
    GenServer.call(pid, {:set_filters, filters})
  end

  @doc """
  Set bus error filter
  """
  @spec set_error_filter(GenServer.server(), integer) :: :ok
  def set_error_filter(pid, filter) do
    GenServer.call(pid, {:set_error_filter, filter})
  end

  @impl true
  @spec init({number}) :: {:ok, Excansock.State.t()}
  def init({queue_size}) do
    {:ok, %State{ queue_size: queue_size, queue: :queue.new(), use_queue: queue_size == :infinity || queue_size > 0 }}
  end

  @impl true
  def handle_call({:open, name, canfd}, {from_pid, _}, state = %State{}) do
    if(state.socket != -1) do
      {:reply, {:error, :ebound}, state }
    else
      case Excansock.Nif.excansock_open(name, if(canfd, do: 1, else: 0)) do
        {:ok, socket} ->
          GenServer.cast(self(), :receive)
          {:reply, :ok, %{ state | socket: socket, controlling_process: from_pid } }
        {:error, error} -> {:reply, {:error, error}, state }
      end
    end
  end

  @impl true
  def handle_call(:close, _, state = %State{}) do
    Excansock.Nif.excansock_close(state.socket)
    {:reply, :ok, %State{}}
  end

  @impl true
  def handle_call({:send, frame = %CanFrame{}}, _, state = %State{use_queue: true}) do
    cond do
      state.queue_size != :infinity && :queue.len(state.queue) >= state.queue_size -> {:reply, :full, state}
      :queue.len(state.queue) > 0 ->  {:reply, :ok, %{state | queue: :queue.in(frame, state.queue)}}
      true ->
        case Excansock.Nif.excansock_send_try(state.socket, frame.id, frame.data) do
          :ok -> {:reply, :ok, state}
          :eagain -> {:reply, :ok, %{state | queue: :queue.in(frame, state.queue)}}
        end
    end
  end

  @impl true
  def handle_call({:send, frame = %CanFrame{}}, _, state = %State{use_queue: false}) do
    case Excansock.Nif.excansock_send_try(state.socket, frame.id, frame.data) do
      :ok -> {:reply, :ok, state}
      :eagain -> {:reply, :full, state}
    end
  end

  @impl true
  def handle_call({:recv_own_messages, enabled}, _, state = %State{}) do
    value = if enabled, do: 1, else: 0
    :ok = Excansock.Nif.excansock_recv_own_messages(state.socket, value)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_loopback, enabled}, _, state = %State{}) do
    value = if enabled, do: 1, else: 0
    :ok = Excansock.Nif.excansock_set_loopback(state.socket, value)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_filters, fs}, _, state = %State{}) do
    bytes = for(f <- fs, into: [], do: {f.can_id, f.can_mask})
    :ok = Excansock.Nif.excansock_set_filters(state.socket, bytes)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_error_filter, mask}, _, state = %State{}) do
    :ok = Excansock.Nif.excansock_set_error_filter(state.socket, mask)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:receive, state) do
    receive_frame(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:select, _socket, _ref, :ready_input}, state) do
    {:noreply, receive_frame(state)}
  end

  @impl true
  def handle_info({:select, _socket, _ref, :ready_output}, state) do
    {:noreply, send_frame(state)}
  end

  defp send_frame(state = %State{}) do
    case :queue.out(state.queue) do
      {:empty, _} -> state
      {{:value, frame}, queue_n} ->
        case Excansock.Nif.excansock_send_try(state.socket, frame.id, frame.data) do
          :eagain -> state
          :ok -> send_frame(%{state | queue: queue_n})
        end
    end
  end

  defp receive_frame(state = %State{}) do
    case Excansock.Nif.excansock_recv_try(state.socket) do
      :eagain ->
        state
      {:can_frame, can_id, data} ->
        process_incoming_frame(can_id, data, state)
        receive_frame(state)
    end
  end

  defp process_incoming_frame(id, data, state = %State{}) do
    can_frame = %CanFrame{
      id: id,
      data: data,
    }

    cond do
      (can_frame.id &&& canERR_FLAG()) > 0 ->
        Kernel.send(state.controlling_process, {:can_error_frame, %{ can_frame | id: can_frame.id &&& ~~~canERR_FLAG() }})
      (can_frame.id &&& canRTR_FLAG()) > 0 ->
        Kernel.send(state.controlling_process, {:can_rtr_frame, %{ can_frame | id: can_frame.id &&& ~~~canRTR_FLAG() }})
      (can_frame.id &&& canEFF_FLAG()) > 0 ->
        Kernel.send(state.controlling_process, {:can_extended_frame, %{ can_frame | id: can_frame.id &&& ~~~canEFF_FLAG() }})
      true ->
        Kernel.send(state.controlling_process, {:can_data_frame, can_frame})
    end

    {:noreply, state}
  end

end
