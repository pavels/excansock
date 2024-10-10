defmodule ExcansockTest do
  use ExUnit.Case
  doctest Excansock

  test "initalize can interface" do
    {:ok, pid} = Excansock.start_link()
    :ok = Excansock.open(pid, "vcan0")
    :ok = Excansock.close(pid)
  end

  test "fail on double bind" do
    {:ok, pid} = Excansock.start_link()
    :ok = Excansock.open(pid, "vcan0")
    {:error, :ebound} = Excansock.open(pid, "vcan0")
    :ok = Excansock.close(pid)
  end

  test "set_filters" do
    {:ok, pid} = Excansock.start_link()
    :ok = Excansock.open(pid, "vcan0")
    :ok = Excansock.set_filters(pid, [
      %Excansock.CanFilter {
        can_id: 0x200,
        can_mask: 0x700,
      }
    ])
    :ok = Excansock.close(pid)
  end

  test "send and receive data" do
    {:ok, pid} = Excansock.start_link(queue_size: :infinity)
    :ok = Excansock.open(pid, "vcan0")

    Excansock.recv_own_messages(pid, true)

    count = 100

    Enum.each(1..count, fn(x) ->
      orig_frame = %Excansock.CanFrame{
        id: 1,
        data: <<1, 2, 3, 4, x>>
      }

      :ok = Excansock.send(pid, orig_frame)
    end)

    Enum.each(1..count, fn(x) ->
      orig_frame = %Excansock.CanFrame{
        id: 1,
        data: <<1, 2, 3, 4, x>>
      }

      receive do
        {:can_data_frame, frame = %Excansock.CanFrame{}} -> assert frame == orig_frame
        msg -> flunk("Wrong message #{inspect msg}")
      after
        # time is in milliseconds
        100 -> flunk("No message received")
      end
    end)

    :ok = Excansock.close(pid)
  end

  test "send and receive real data - different id" do
    can_interface = System.get_env("REAL_CAN_INTERFACE")
    if(can_interface != nil) do
      run_real_test(can_interface, 1, 2)
    end
  end

  test "send and receive real data - same id" do
    can_interface = System.get_env("REAL_CAN_INTERFACE")
    if(can_interface != nil) do
      run_real_test(can_interface, 3, 3)
    end
  end

  defp run_real_test(can_interface, tx_can_id, rx_can_id) do
    {:ok, pid} = Excansock.start_link(queue_size: :infinity)
    :ok = Excansock.open(pid, can_interface)

    count = 1000

    Enum.each(1..count, fn(x) ->
      orig_frame = %Excansock.CanFrame{
        id: tx_can_id,
        data: <<1, 2, 3, 4, x::16>>
      }

      :ok = Excansock.send(pid, orig_frame)
    end)

    Enum.each(1..count, fn(x) ->
      orig_frame = %Excansock.CanFrame{
        id: rx_can_id,
        data: <<1, 2, 3, 4, x::16>>
      }

      receive do
        {:can_data_frame, frame = %Excansock.CanFrame{}} -> assert frame == orig_frame
      after
        # time is in milliseconds
        5000 -> flunk("No message received")
      end
    end)

    :ok = Excansock.close(pid)
  end

end
