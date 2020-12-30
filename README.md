# knife-bmc

A Chef Knife plugin for managing and provisioning cloud resources on PhoenixNAP BMC. See https://developers.phoenixnap.com/resources.

## Installing the Plugin

The plugin is available as a Ruby gem.

```sh
gem install knife-bmc
```

## Running the plugin with Knife

Setup your PhoenixNAP BMC credentials:

1. login to your account at [PhoenixNAP](https://bmc.phoenixnap.com) and create a new OAuth application.
2. Save those credentials in a new file at `$HOME/.pnap/config`. 

The file contents must be YAML and take the form:

```yaml
client_id: <YOUR_OAUTH_CLIENT_ID>
client_secret: <YOUR_OAUTH_CLIENT_SECRET>
```

If the gem has been installed on your system then it should already be available as a `knife` subcommands:

    knife bmc server create (OPTIONS) HOSTNAME
    knife bmc server delete (OPTIONS) SERVER_LIST
    knife bmc server get (OPTIONS) SERVER_LIST
    knife bmc server list (OPTIONS)
    knife bmc server poweroff (OPTIONS) SERVER_LIST
    knife bmc server poweron (OPTIONS) SERVER_LIST
    knife bmc server reboot (OPTIONS) SERVER_LIST
    knife bmc server reset (OPTIONS) SERVER_ID_LIST
    knife bmc server shutdown (OPTIONS) SERVER_LIST
    knife bmc sshkey create (OPTIONS) KEYFILE
    knife bmc sshkey delete (OPTIONS)
    knife bmc sshkey list

