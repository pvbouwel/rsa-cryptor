#!/bin/bash

# As from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

PREREQS="$(echo "$0" | sed 's/decrypt_file.sh/check_prerequisites.sh/')"
. ${PREREQS}

POSITIONAL_ARGS=()
HELP_TEXT="decrypt_file.sh\nArguments:"
HELP_TEXT="${HELP_TEXT}\n\t mandatory: -f|--file   The encrypted file (should end in .encrypted)"
HELP_TEXT="${HELP_TEXT}\n\t mandatory: -k|--key    The private rsa key to be used to decrypt the file"
HELP_TEXT="${HELP_TEXT}\n\t optional : --overwrite Whether existing files can be overwritten (still prompt for confirmation)"

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

if ! echo "$FILE" | grep ".encrypted$" &>/dev/null
then
  echo "Input file should end in .encrypted extension"
  exit 1
fi

TARGET_FILE="$(echo "$FILE" | sed 's/\.encrypted$//')"
if [ "${TARGET_FILE}.encrypted" != "$FILE" ]
then
  echo "Sanity check failed for ${TARGET_FILE}"
  exit 1
fi

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
TARGET_ENCRYPTION_ENCKEY="${TARGET_FILE}.enckey"
TARGET_ENCRYPTION_PLAINKEY="${TARGET_FILE}.tmp.enckey"

assert_is_valid_file TARGET_ENCRYPTION_ENCKEY

if grep "BEGIN  PRIVATE KEY" $KEY
then
  PEM_KEY="$KEY"
else
  PEM_KEY="$KEY.pem"
  assert_is_not_a_file "$PEM_KEY" "The provided key is not of PEM format we will convert it to pem here"
  cp -v "$KEY" "$PEM_KEY"
  ssh-keygen -f "$PEM_KEY" -N '' -p -m pem
  chmod 600 "$PEM_KEY"
fi

assert_is_not_a_file ${TARGET_ENCRYPTION_PLAINKEY} "We would place the decrypted file here"
echo "Creating ${TARGET_ENCRYPTION_PLAINKEY}"
if ! openssl pkeyutl -decrypt -inkey "${PEM_KEY}" -in "${TARGET_ENCRYPTION_ENCKEY}" -out "${TARGET_ENCRYPTION_PLAINKEY}" &>/dev/null
then
    echo "FAIL: Was not able to decrypt the encryption key with the provided public key (was it PEM or ssh-rsa format and was it the correct key?)"
    echo "Running again with output to give debug info"
    openssl pkeyutl -decrypt -inkey "${PEM_KEY}" -in "${TARGET_ENCRYPTION_ENCKEY}" -out "${TARGET_ENCRYPTION_PLAINKEY}"
    exit 1
fi

rm $PEM_KEY

if ! openssl enc -d -p -aes-256-cbc -salt -in "$FILE" -out "${TARGET_FILE}" -pass "file:${TARGET_ENCRYPTION_PLAINKEY}" &>/dev/null
then
    echo "FAIL: Was not able decrypt the file with the decrypted encryption key"
    echo "Running again with output"
    openssl dec -p -aes-256-cbc -salt -in "$FILE" -out "${TARGET_FILE}" -pass "file:${TARGET_ENCRYPTION_PLAINKEY}"
    exit 1
fi

rm "${TARGET_ENCRYPTION_PLAINKEY}"

echo "The decrypted file ${TARGET_FILE} is available" 