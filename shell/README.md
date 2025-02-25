# rsa-cryptor-scripts

Scripts that glue together existing Linux tools in order to encrypt and decrypt data using an RSA key as base key material.  It performs a form of envelope encryption where a random 256 bit key is generated for AES encryption and the AES key is encrypted asymetrically using RSA.

Common use case where Alice has secret information she wants to share with Bob:

1) Bob creates an ssh key pair (e.g. `ssh-keygen -t rsa -b 2048 -f /home/bob/communication_key/rsa`) (if he doesn't have one already)
2) Bob sends the public part (/home/bob/communication_key/rsa.pub) of his key to Alice.
3) Alice has a file very_secret.file that she wants to send to bob she encrypts it using `encrypt_file.sh -f very_secret.file -k /files/from/bob/rsa3.pub` and sends the resulting files very_secret.file.enckey and very_secret.file.encrypted to Bob.
4) Upon arrival of the files Bob eagerly performs the decryption process `decrypt_file.sh -f very_secret.file.encrypted -k /home/bob/communication_key/rsa` and he can read all secrets in the resulting file name very_secret.file


Inspired by: https://kulkarniamit.github.io/whatwhyhow/howto/encrypt-decrypt-file-using-rsa-public-private-keys.html


## Installation

You can chose whatever way you want to get the scripts in place but easiest way is to go somewhere on your computer where you want to keep them.
Then clone the git repo and add the shell directory to your path. The following command does the cloning and shows the statement to run or to add to your shell rc file (if you want it available in every shell in the future):
```
git clone git@github.com:pvbouwel/rsa-cryptor.git && cd rsa-cryptor && echo -e "Add export statement to your shell initialization if you want to use the scripts from anywhere and open a new shell\n\texport PATH=\"\$PATH:$(pwd)/shell\""
```