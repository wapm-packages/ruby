# frozen_string_literal: true

RSpec.describe "ruby requirement" do
  def locked_ruby_version
    Bundler::RubyVersion.from_string(Bundler::LockfileParser.new(File.read(bundled_app_lock)).ruby_version)
  end

  # As discovered by https://github.com/rubygems/bundler/issues/4147, there is
  # no test coverage to ensure that adding a gem is possible with a ruby
  # requirement. This test verifies the fix, committed in bfbad5c5.
  it "allows adding gems" do
    install_gemfile <<-G
      source "https://gem.repo1"
      ruby "#{Gem.ruby_version}"
      gem "myrack"
    G

    install_gemfile <<-G
      source "https://gem.repo1"
      ruby "#{Gem.ruby_version}"
      gem "myrack"
      gem "myrack-obama"
    G

    expect(the_bundle).to include_gems "myrack-obama 1.0"
  end

  it "allows removing the ruby version requirement" do
    install_gemfile <<-G
      source "https://gem.repo1"
      ruby "~> #{Gem.ruby_version}"
      gem "myrack"
    G

    expect(lockfile).to include("RUBY VERSION")

    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack"
    G

    expect(the_bundle).to include_gems "myrack 1.0.0"
    expect(lockfile).not_to include("RUBY VERSION")
  end

  it "allows changing the ruby version requirement to something compatible" do
    install_gemfile <<-G
      source "https://gem.repo1"
      ruby ">= #{current_ruby_minor}"
      gem "myrack"
    G

    allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)
    expect(locked_ruby_version).to eq(Bundler::RubyVersion.system)

    install_gemfile <<-G
      source "https://gem.repo1"
      ruby ">= #{Gem.ruby_version}"
      gem "myrack"
    G

    expect(the_bundle).to include_gems "myrack 1.0.0"
    expect(locked_ruby_version).to eq(Bundler::RubyVersion.system)
  end

  it "allows changing the ruby version requirement to something incompatible" do
    install_gemfile <<-G
      source "https://gem.repo1"
      ruby ">= 1.0.0"
      gem "myrack"
    G

    lockfile <<~L
      GEM
        remote: https://gem.repo1/
        specs:
          myrack (1.0.0)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        myrack

      RUBY VERSION
         ruby 2.1.4p422

      BUNDLED WITH
         #{Bundler::VERSION}
    L

    allow(Bundler::SharedHelpers).to receive(:find_gemfile).and_return(bundled_app_gemfile)

    install_gemfile <<-G
      source "https://gem.repo1"
      ruby ">= #{current_ruby_minor}"
      gem "myrack"
    G

    expect(the_bundle).to include_gems "myrack 1.0.0"
    expect(locked_ruby_version).to eq(Bundler::RubyVersion.system)
  end

  it "allows requirements with trailing whitespace" do
    install_gemfile <<-G
      source "https://gem.repo1"
      ruby "#{Gem.ruby_version}\\n \t\\n"
      gem "myrack"
    G

    expect(the_bundle).to include_gems "myrack 1.0.0"
  end

  it "fails gracefully with malformed requirements" do
    install_gemfile <<-G, raise_on_error: false
      source "https://gem.repo1"
      ruby ">= 0", "-.\\0"
      gem "myrack"
    G

    expect(err).to include("There was an error parsing") # i.e. DSL error, not error template
  end

  it "allows picking up ruby version from a file" do
    create_file ".ruby-version", Gem.ruby_version.to_s

    install_gemfile <<-G
      source "https://gem.repo1"
      ruby file: ".ruby-version"
      gem "myrack"
    G

    expect(lockfile).to include("RUBY VERSION")
  end

  it "reads the ruby version file from the right folder when nested Gemfiles are involved" do
    create_file ".ruby-version", Gem.ruby_version.to_s

    gemfile <<-G
      source "https://gem.repo1"
      ruby file: ".ruby-version"
      gem "myrack"
    G

    nested_dir = bundled_app(".ruby-lsp")

    FileUtils.mkdir nested_dir

    gemfile ".ruby-lsp/Gemfile", <<-G
      eval_gemfile(File.expand_path("../Gemfile", __dir__))
    G

    bundle "install", dir: nested_dir

    expect(bundled_app(".ruby-lsp/Gemfile.lock").read).to include("RUBY VERSION")
  end
end
