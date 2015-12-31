dovetail is an implementation of the [IP over MIME](https://tools.ietf.org/html/draft-eastlake-ip-mime-10) draft using E-Mail as transport

# Depencies

```bash
bundle install
```

# Preparations
dovetail does point-to-point connections. You will need two devices and two email addresses.

# Usage
Each end needs to run the following command

```bash
./dovetail --destination email1@host.org --source email2@host.org  --imap-server imap.host.org --imap-user email2 \
	--imap-password 123456 --smtp-server smtp.host.org --smtp-user email2 --smtp-password 123456 --ip-address 10.42.0.1
```

Please replace the respective params. source and destination email need to be swapped on both ends. user, server and password need to be adjusted. Obviously also the ip needs to be changed.

# Notes

Currently the netmask is hardcoded to /24
