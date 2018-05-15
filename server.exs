#!/usr/bin/env elixir

defmodule Accepter do
  require Logger

  defstruct [:listen_socket]

  def listen() do
    portno =
      case System.argv() do
        [arg] ->
          {portno, ""} = Integer.parse(arg)
          portno
        [] ->
          8080
      end
    opts = [:binary, active: false, reuseaddr: true]
    :ok = Logger.info("Attempting to listen on #{portno}")
    {:ok, socket} = :gen_tcp.listen(portno, opts)
    :ok = Logger.info("Listening on #{portno}")
    socket
  end

  def loop(%__MODULE__{} = data) do
    :ok =
      case :gen_tcp.accept(data.listen_socket, 5000) do
        {:ok, socket} ->
          :ok = Receiver.add_socket(socket)
          Logger.info("Connection accepted")
        {:error, :timeout} ->
          Logger.info("Accept timeout")
      end
    loop(data)
  end

  def start() do
    data =
      %__MODULE__{}
      |> struct!(listen_socket: listen())
    pid = spawn_link(fn -> loop(data) end)
    {:ok, pid}
  end
end

defmodule Receiver do
  require Logger

  defstruct []

  def add_socket(socket) do
    receiver = Process.whereis(__MODULE__)
    :ok = :gen_tcp.controlling_process(socket, receiver)
    _ = send(receiver, {:add_socket, socket})
    :ok
  end

  def loop(%__MODULE__{} = data) do
    _ =
      receive do
        {:add_socket, socket} ->
          Logger.info("Socket added")
          :inet.setopts(socket, active: :once)
        {:tcp, socket, _} ->
          :ok = :gen_tcp.send(socket, response())
          Logger.info("Response sent")
          :inet.setopts(socket, active: :once)
        _ ->
          :noop
      after
        5000 ->
          Logger.info("Receive timeout")
      end
    loop(data)
  end

  def response() do
    content = File.read!("teapot.jpg")
    date =
      case DateTime.utc_now() do
        dt ->
          day_of_week =
            case Calendar.ISO.day_of_week(dt.year, dt.month, dt. day) do
              1 ->
                "Sun"
              2 ->
                "Mon"
              3 ->
                "Tue"
              4 ->
                "Wed"
              5 ->
                "Thu"
              6 ->
                "Fri"
              7 ->
                "Sat"
            end
          day_of_month =
            case dt.day do
              day when day in 1..9 ->
                ["0", "#{day}"]
              day ->
                "#{day}"
            end
          month =
            case dt.month do
              1 ->
                "Jan"
              2 ->
                "Feb"
              3 ->
                "Mar"
              4 ->
                "Apr"
              5 ->
                "May"
              6 ->
                "Jun"
              7 ->
                "Jul"
              8 ->
                "Aug"
              9 ->
                "Sep"
              10 ->
                "Oct"
              11 ->
                "Nov"
              12 ->
                "Dec"
            end
          "#{day_of_week}, #{day_of_month} #{month} #{dt.year} #{dt.hour}:#{dt.minute}:#{dt.second} #{dt.zone_abbr}"
      end

    clrf = "\r\n"
    status_line = ["HTTP/1.1 418 OK", clrf]
    headers = [
      ["Content-Type: image/jpeg", clrf],
      ["Content-Length: ", "#{IO.iodata_length(content)}", clrf],
      ["Date: ", date, clrf]
    ]
    body = [content, clrf]
    [status_line, headers, clrf, body]
  end

  def start() do
    data = struct!(__MODULE__, [])
    pid = spawn_link(fn -> loop(data) end)
    true = Process.register(pid, __MODULE__)
    {:ok, pid}
  end
end

defmodule Server do
  def loop() do
    receive do
      5000 ->
        loop()
    end
  end

  def start() do
    {:ok, _} = Receiver.start()
    {:ok, _} = Accepter.start()
    loop()
  end
end

Server.start()
