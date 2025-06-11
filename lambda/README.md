# SolarWinds Lambda Ruby Layer

## Building Lambda Ruby Layer with OpenTelemetry Ruby Dependencies Using SAM

Build

```bash
sam build -u -t template.yml -e BUNDLE_RUBYGEMS__PKG__GITHUB__COM=<your_github_token>
```

Make sure the layer structure like below with your zip

```console
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

Zip the layer to file

```bash
cd .aws-sam/build/OTelLayer/
zip -qr ../../../<your_layer_name>.zip ruby/
cd -
```

## Building Lambda Ruby Layer with build-ruby Docker image

Execute the following command to build layer that is compatiable with 3.2, 3.3 and 3.4

```bash
./build.sh
```
