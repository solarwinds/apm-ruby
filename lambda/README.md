# SolarWinds Lambda Ruby Layer

## Building Lambda Ruby Layer With OpenTelemetry Ruby Dependencies

Build
```bash
sam build -u -t template.yml -e BUNDLE_RUBYGEMS__PKG__GITHUB__COM=<your_github_token>
```

Make sure the layer structure like below with your zip
```
ruby
    └── gems
        └── 3.2.0
            ├── build_info
            ├── doc
            ├── extensions
            ├── gems
            ├── plugins
            └── specifications
```

Zip the file for uploading to ruby lambda layer

```bash
cd .aws-sam/build/OTelLayer/
zip -qr ../../../<your_layer_name>.zip ruby/
cd -
# or run following script
zip_ruby_layer.sh -n <your_layer_name>
```
