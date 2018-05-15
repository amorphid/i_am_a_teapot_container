FROM elixir
COPY teapot.jpg .
COPY server.exs .
ENTRYPOINT ["elixir", "server.exs"]
CMD []
