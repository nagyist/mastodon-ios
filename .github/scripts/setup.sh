#!/bin/bash

brew install swiftgen
brew install sourcery

# Install Ruby Bundler
gem install bundler:2.5.21

# Install Ruby Gems
bundle install

# Setup notification endpoint
bundle exec arkana
