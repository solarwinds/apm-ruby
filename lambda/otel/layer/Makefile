
build-OTelLayer:
	mkdir -p $(ARTIFACTS_DIR)/ruby/gems/3.2.0
	mkdir -p $(ARTIFACTS_DIR)/solarwinds-apm/
	bundle config set --global silence_root_warning 1
	bundle config set --local path 'ruby'
	bundle install
	cp -r ruby/ruby/3.2.0/* $(ARTIFACTS_DIR)/ruby/gems/3.2.0
	cp otel_wrapper.rb $(ARTIFACTS_DIR)/otel_wrapper.rb
	cp wrapper $(ARTIFACTS_DIR)/solarwinds-apm/
	rm -rf $(ARTIFACTS_DIR)/ruby/gems/3.2.0/cache
