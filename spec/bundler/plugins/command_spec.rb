# frozen_string_literal: true

RSpec.describe "command plugins" do
  before do
    build_repo2 do
      build_plugin "command-mah" do |s|
        s.write "plugins.rb", <<-RUBY
          module Mah
            class Plugin < Bundler::Plugin::API
              command "mahcommand" # declares the command

              def exec(command, args)
                puts "MahHello"
              end
            end
          end
        RUBY
      end
    end

    bundle "plugin install command-mah --source https://gem.repo2"
  end

  it "executes without arguments" do
    expect(out).to include("Installed plugin command-mah")

    bundle "mahcommand"
    expect(out).to eq("MahHello")
  end

  it "accepts the arguments" do
    update_repo2 do
      build_plugin "the-echoer" do |s|
        s.write "plugins.rb", <<-RUBY
          module Resonance
            class Echoer
              # Another method to declare the command
              Bundler::Plugin::API.command "echo", self

              def exec(command, args)
                puts "You gave me \#{args.join(", ")}"
              end
            end
          end
        RUBY
      end
    end

    bundle "plugin install the-echoer --source https://gem.repo2"
    expect(out).to include("Installed plugin the-echoer")

    bundle "echo tacos tofu lasange"
    expect(out).to eq("You gave me tacos, tofu, lasange")
  end

  it "raises error on redeclaration of command" do
    update_repo2 do
      build_plugin "copycat" do |s|
        s.write "plugins.rb", <<-RUBY
          module CopyCat
            class Cheater < Bundler::Plugin::API
              command "mahcommand", self

              def exec(command, args)
              end
            end
          end
        RUBY
      end
    end

    bundle "plugin install copycat --source https://gem.repo2", raise_on_error: false

    expect(out).not_to include("Installed plugin copycat")

    expect(err).to include("Failed to install plugin `copycat`, due to Bundler::Plugin::Index::CommandConflict (Command(s) `mahcommand` declared by copycat are already registered.)")
  end
end
