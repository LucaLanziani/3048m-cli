# 3048m-cli

Download:

```
curl -O https://raw.githubusercontent.com/LucaLanziani/3048m-cli/master/3048m.sh
```

Fix permission:

```
chmod +x ./3048m.sh
```

Run:

```
./3048m.sh
```

The script will try to load your username and password from `~/.3048m`.
If the file is not present the script will ask you to enter username and password.

Example of `~/.3048m`:

```
USERNAME=username@test.com
PASSWORD=plaintextpassword
```

# THAT IS UNSAFE!!!

The script support a PGP encrypted password.

Example of `~/.3048m`:

```
USERNAME=username@test.com
PASSWORD_PGP="
-----BEGIN PGP MESSAGE-----

...
...
...
...
-----END PGP MESSAGE-----
"
```

`PASSWORD_PGP` can be generate using:

```
gpg2 -aer <your email>
```

You can then enter the password and press CTRL-D