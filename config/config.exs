# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :sketchpad,
  ecto_repos: [Sketchpad.Repo]

# Configures the endpoint
config :sketchpad, Sketchpad.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "BCqHloAfzORpn/TX90PB9GULWVRZpjwegD4U8T1on/RUmEYTjkVGLC2YKFhkhLiS",
  render_errors: [view: Sketchpad.ErrorView, accepts: ~w(html json)],
  check_origin: false,
  pubsub: [name: Sketchpad.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
