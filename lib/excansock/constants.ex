defmodule Excansock.CanConstants do

  defmacro canEFF_FLAG, do: 0x80000000  # Extended frame format
  defmacro canRTR_FLAG, do: 0x40000000  # Request for transmission
  defmacro canERR_FLAG, do: 0x20000000  # Error frame, input frame only

  defmacro canSFF_MASK, do: 0x7ff
  defmacro canEFF_MASK, do: 0x1fffffff
  defmacro canERR_MASK, do: 0x1fffffff

  defmacro canSFF_INVALID, do: 0x7f0
  defmacro canEFF_INVALID, do: 0x1fc00000

  defmacro canNO_TIMESTAMP, do: -1

  # error class (mask) in can_id
  defmacro canERR_TX_TIMEOUT,   do: 0x00000001 # TX timeout (by netdevice driver)
  defmacro canERR_LOSTARB,      do: 0x00000002 # lost arbitration    / data[0]
  defmacro canERR_CRTL,         do: 0x00000004 # controller problems / data[1]
  defmacro canERR_PROT,         do: 0x00000008 # protocol violations / data[2..3]
  defmacro canERR_TRX,          do: 0x00000010 # transceiver status  / data[4]
  defmacro canERR_ACK,          do: 0x00000020 # received no ACK on transmission
  defmacro canERR_BUSOFF,       do: 0x00000040 # bus off
  defmacro canERR_BUSERROR,     do: 0x00000080 # bus error (may flood!)
  defmacro canERR_RESTARTED,    do: 0x00000100 # controller restarted

  # arbitration lost in bit ... / data[0]
  defmacro canERR_LOSTARB_UNSPEC,   do: 0x00 # unspecified
				                                     # else bit number in bitstream

  # error status of CAN-controller / data[1]
  defmacro canERR_CRTL_UNSPEC,      do: 0x00 # unspecified
  defmacro canERR_CRTL_RX_OVERFLOW, do: 0x01 # RX buffer overflow
  defmacro canERR_CRTL_TX_OVERFLOW, do: 0x02 # TX buffer overflow
  defmacro canERR_CRTL_RX_WARNING,  do: 0x04 # reached warning level for RX errors
  defmacro canERR_CRTL_TX_WARNING,  do: 0x08 # reached warning level for TX errors
  defmacro canERR_CRTL_RX_PASSIVE,  do: 0x10 # reached error passive status RX
  defmacro canERR_CRTL_TX_PASSIVE,  do: 0x20 # reached error passive status TX
				                                     # (at least one error counter exceeds
				                                     # the protocol-defined level of 127)

  # error in CAN protocol (type) / data[2]
  defmacro canERR_PROT_UNSPEC,      do: 0x00 # unspecified
  defmacro canERR_PROT_BIT,         do: 0x01 # single bit error
  defmacro canERR_PROT_FORM,        do: 0x02 # frame format error
  defmacro canERR_PROT_STUFF,       do: 0x04 # bit stuffing error
  defmacro canERR_PROT_BIT0,        do: 0x08 # unable to send dominant bit
  defmacro canERR_PROT_BIT1,        do: 0x10 # unable to send recessive bit
  defmacro canERR_PROT_OVERLOAD,    do: 0x20 # bus overload
  defmacro canERR_PROT_ACTIVE,      do: 0x40 # active error announcement
  defmacro canERR_PROT_TX,          do: 0x80 # error occured on transmission

  # error in CAN protocol (location) / data[3]
  defmacro canERR_PROT_LOC_UNSPEC,  do: 0x00 # unspecified
  defmacro canERR_PROT_LOC_SOF,     do: 0x03 # start of frame
  defmacro canERR_PROT_LOC_ID28_21, do: 0x02 # ID bits 28 - 21 (SFF: 10 - 3)
  defmacro canERR_PROT_LOC_ID20_18, do: 0x06 # ID bits 20 - 18 (SFF: 2 - 0 )
  defmacro canERR_PROT_LOC_SRTR,    do: 0x04 # substitute RTR (SFF: RTR)
  defmacro canERR_PROT_LOC_IDE,     do: 0x05 # identifier extension
  defmacro canERR_PROT_LOC_ID17_13, do: 0x07 # ID bits 17-13
  defmacro canERR_PROT_LOC_ID12_05, do: 0x0F # ID bits 12-5
  defmacro canERR_PROT_LOC_ID04_00, do: 0x0E # ID bits 4-0
  defmacro canERR_PROT_LOC_RTR,     do: 0x0C # RTR
  defmacro canERR_PROT_LOC_RES1,    do: 0x0D # reserved bit 1
  defmacro canERR_PROT_LOC_RES0,    do: 0x09 # reserved bit 0
  defmacro canERR_PROT_LOC_DLC,     do: 0x0B # data length code
  defmacro canERR_PROT_LOC_DATA,    do: 0x0A # data section
  defmacro canERR_PROT_LOC_CRC_SEQ, do: 0x08 # CRC sequence
  defmacro canERR_PROT_LOC_CRC_DEL, do: 0x18 # CRC delimiter
  defmacro canERR_PROT_LOC_ACK,     do: 0x19 # ACK slot
  defmacro canERR_PROT_LOC_ACK_DEL, do: 0x1B # ACK delimiter
  defmacro canERR_PROT_LOC_EOF,     do: 0x1A # end of frame
  defmacro canERR_PROT_LOC_INTERM,  do: 0x12 # intermission

  # error status of CAN-transceiver / data[4]
  #                                                  CANH CANL
  defmacro canERR_TRX_UNSPEC,             do: 0x00 # 0000 0000
  defmacro canERR_TRX_CANH_NO_WIRE,       do: 0x04 # 0000 0100
  defmacro canERR_TRX_CANH_SHORT_TO_BAT,  do: 0x05 # 0000 0101
  defmacro canERR_TRX_CANH_SHORT_TO_VCC,  do: 0x06 # 0000 0110
  defmacro canERR_TRX_CANH_SHORT_TO_GND,  do: 0x07 # 0000 0111
  defmacro canERR_TRX_CANL_NO_WIRE,       do: 0x40 # 0100 0000
  defmacro canERR_TRX_CANL_SHORT_TO_BAT,  do: 0x50 # 0101 0000
  defmacro canERR_TRX_CANL_SHORT_TO_VCC,  do: 0x60 # 0110 0000
  defmacro canERR_TRX_CANL_SHORT_TO_GND,  do: 0x70 # 0111 0000
  defmacro canERR_TRX_CANL_SHORT_TO_CANH, do: 0x80 # 1000 0000

  # controller specific additional information / data[5..7]

end
