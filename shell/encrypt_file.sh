#!/bin/bash

# As from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

PREREQS="$(echo "$0" | sed 's/encrypt_file.sh/check_prerequisites.sh/')"
. ${PREREQS}

POSITIONAL_ARGS=()


HELP_TEXT="decrypt_file.sh\nArguments:"
HELP_TEXT="encrypt_file.sh\nArguments:"
HELP_TEXT="${HELP_TEXT}\n\t mandatory:  -f|--file     The file to encrypt"
HELP_TEXT="${HELP_TEXT}\n\t mandatory:  -k|--key      The public rsa key to be used to encrypt the file"
HELP_TEXT="${HELP_TEXT}\n\t optional :   --overwrite  Whether existing files can be overwritten (still prompt for confirmation)"

function usage {
    echo "USAGE:"
    echo -e "$HELP_TEXT"
    exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--file)
      FILE="$2"
      shift # past argument
      shift # past value
      ;;
    -k|--key)
      KEY="$2"
      shift # past argument
      shift # past value
      ;;
    --debug)
      DEBUG=YES
      shift # past argument
      ;;
    --overwrite)
      OVERWRITE="Y"
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      usage
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

function assert_not_empty {
    ARG_NAME="$1"
    ARG_FLAGS="$2"

    if [ "X${!ARG_NAME}" = "X" ]
    then
      echo "$ARG_NAME ($ARG_FLAGS) argument is mandatory"
      usage
    fi
}

function assert_is_valid_file {
    ARG_NAME="$1"
    ARG_FLAGS="$2"

    assert_not_empty "$1" "$2"
    FILE_NAME="${!ARG_NAME}"
    if [ ! -f "$FILE_NAME" ]
    then
      echo "Could not find the $ARG_NAME ($ARG_FLAGS) file ($FILE_NAME)"
      exit 1
    fi
}

assert_is_valid_file "FILE" "--file|-f"
assert_is_valid_file "KEY" "--key|-k"

TARGET_ENCRYPTED_FILE_NAME="${FILE}.encrypted"
TARGET_ENCRYPTION_ENCKEY="${FILE}.enckey"
TARGET_ENCRYPTION_PLAINKEY="${FILE}.tmp.enckey"

function assert_is_not_a_file {
    FILE_NAME="$1"
    REASON="$2"

    if [ -f "$FILE_NAME" ]
    then
      if [ "$OVERWRITE" == "Y" ]
      then
        echo "We will overwrite $FILE_NAME (${REASON}). Press ctrl+c to abort or enter to continue..."
        read fff
        return
      fi
      echo "FILE $FILE_NAME already exists which is not allowed (${REASON})"
      exit 1
    fi
}

assert_is_not_a_file ${TARGET_ENCRYPTED_FILE_NAME} "We would place the encrypted file here"
assert_is_not_a_file ${TARGET_ENCRYPTION_ENCKEY} "We would store the encrypted encryption key here"
assert_is_not_a_file ${TARGET_ENCRYPTION_PLAINKEY} "We would store the plaintext encryption key here (temporarily)"

if grep "BEGIN RSA PUBLIC KEY" $KEY
then
  PEM_KEY="$KEY"
else
  PEM_KEY="$KEY.pem"
  assert_is_not_a_file "$PEM_KEY" "The provided key is not of PEM format we will convert it to pem here"
  ssh-keygen -f "$KEY" -e -m pem >"$PEM_KEY"
fi

if ! openssl rand -hex -out ${TARGET_ENCRYPTION_PLAINKEY} 32
then
    echo "FAIL: Was not able to generate encryption key"
    exit 1
fi

if ! openssl enc -p -aes-256-cbc -salt -in "$FILE" -out "${TARGET_ENCRYPTED_FILE_NAME}" -pass "file:${TARGET_ENCRYPTION_PLAINKEY}" &>/dev/null
then
    echo "FAIL: Was not able to encrypt the file with the generated encryption key"
    echo "Running again with output"
    openssl enc -p -aes-256-cbc -salt -in "$FILE" -out "${TARGET_ENCRYPTED_FILE_NAME}" -pass "file:${TARGET_ENCRYPTION_PLAINKEY}" 
    exit 1
fi

if ! openssl pkeyutl -encrypt -inkey "${PEM_KEY}" -pubin -in "${TARGET_ENCRYPTION_PLAINKEY}" -out "${TARGET_ENCRYPTION_ENCKEY}" &>/dev/null
then
    echo "FAIL: Was not able to encrypt the encryption key with the provided public key (was it PEM or ssh-rsa format?)"
    echo "Running again with output to give debug info"
    openssl pkeyutl -encrypt -inkey "${PEM_KEY}" -pubin -in "${TARGET_ENCRYPTION_PLAINKEY}" -out "${TARGET_ENCRYPTION_ENCKEY}"
    exit 1
fi

rm "${TARGET_ENCRYPTION_PLAINKEY}"

echo "You can send '$TARGET_ENCRYPTION_ENCKEY' and '$TARGET_ENCRYPTED_FILE_NAME' to the owner of the private part of $KEY" 