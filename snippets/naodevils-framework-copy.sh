############################ START FRAMEWORK INSTALLATION ############################

# copy data
if [ -z "$FRAMEWORK_DIR" ]; then
    read -p "Please enter framework path: " FRAMEWORK_DIR
fi

# pull
if [ "${GIT_PULL:-true}" == "true" ]; then
    git -C "$FRAMEWORK_DIR" pull
fi

BUILD_CONFIG="${BUILD_CONFIG:-develop}"

# compile
if [ "${COMPILE:-true}" == "true" ]; then
    (
        cd "$FRAMEWORK_DIR"
        if [ ! -f "Build/nao-$BUILD_CONFIG/CMakeCache.txt" ]; then
            cmake --preset "nao-$BUILD_CONFIG"
        fi
        cmake --build --preset "nao-$BUILD_CONFIG"
    )
fi

# copy
mkdir -p ./root/nao/bin ./root/nao/Config ./root/nao/logs
cp -r "$FRAMEWORK_DIR/Config" ./root/nao
cp "$FRAMEWORK_DIR/Build/nao-$BUILD_CONFIG/naodevils" \
    "$FRAMEWORK_DIR/Build/nao-$BUILD_CONFIG/naodevilsbase" \
    "$FRAMEWORK_DIR/Build/nao-$BUILD_CONFIG/sensorReader" \
    ./root/nao/bin

# copy public ssh key
cat "$FRAMEWORK_DIR/Config/Keys/id_rsa_nao.pub" >> ./root/nao/.ssh/authorized_keys
cat "$FRAMEWORK_DIR/Config/Keys/id_rsa_nao.pub" >> ./root/root/.ssh/authorized_keys

chmod +x ./root/nao/bin/*
chown -R 1001:1001 ./root/nao/bin ./root/nao/Config ./root/nao/logs

# add git commit hashes
GIT_IMAGE="$(git rev-parse --short HEAD)"
GIT_FRAMEWORK="$(git -C "$FRAMEWORK_DIR" rev-parse --short HEAD)"

date > ./root/nao/version_info.txt
echo "Image=$GIT_IMAGE" >> ./root/nao/version_info.txt
echo "Framework=$GIT_FRAMEWORK" >> ./root/nao/version_info.txt


############################ END FRAMEWORK INSTALLATION ############################
