# auto-update

Services that do bootc, flatpak, and sysext updates daily.

## How to use

- Install the sysext
- Copy the some default configs:
  ```
  $ sudo cp -a /usr/etc/systemd/system/bootc-fetch-apply-updates.* /etc/systemd/system/
  ```
- enable bootc auto updates:
  ```
  $ systemctl enable bootc-fetch-apply-updates.timer
  ```
