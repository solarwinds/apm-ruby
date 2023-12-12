
build-OTelLayer:
	mkdir -p ruby
	mkdir -p $(ARTIFACTS_DIR)/ruby/gems/3.2.0
	mkdir -p $(ARTIFACTS_DIR)/ruby/lib/
	bundle config set --global silence_root_warning 1
	bundle config set --local path 'ruby'
	bundle install
	cp -r ruby/ruby/3.2.0/* $(ARTIFACTS_DIR)/ruby/gems/3.2.0
	cp otel-handler $(ARTIFACTS_DIR)/otel-handler
	cp wrapper.rb $(ARTIFACTS_DIR)/ruby/lib/
	rm -rf $(ARTIFACTS_DIR)/ruby/gems/3.2.0/cache
