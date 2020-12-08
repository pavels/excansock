defmodule Excansock.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @nif_not_loaded_err "nif not loaded"

  @moduledoc false

  def load_nif() do
    nif_binary = Application.app_dir(:excansock, "priv/excansock_nif")

    :erlang.load_nif(to_charlist(nif_binary), 0)
  end

  def excansock_open(_device_name, _canfd), do: :erlang.nif_error(@nif_not_loaded_err)
  def excansock_close(_socket), do: :erlang.nif_error(@nif_not_loaded_err)
  def excansock_recv_own_messages(_socket, _value), do: :erlang.nif_error(@nif_not_loaded_err)
  def excansock_set_loopback(_socket, _value), do: :erlang.nif_error(@nif_not_loaded_err)
  def excansock_set_filters(_socket, _bytes), do: :erlang.nif_error(@nif_not_loaded_err)
  def excansock_set_error_filter(_socket, _mask), do: :erlang.nif_error(@nif_not_loaded_err)
  def excansock_send_try(_socket, _canid, _data), do: :erlang.nif_error(@nif_not_loaded_err)
  def excansock_recv_try(_socket), do: :erlang.nif_error(@nif_not_loaded_err)

end
