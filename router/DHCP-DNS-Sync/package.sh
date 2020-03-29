#! /bin/sh

BUILD_DIR=target
PACKAGE_NAME=DHCP-DNS-Sync
OUTPUT_DIR=${1:-.}

rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

echo
echo "*** Copy spk contents to $BUILD_DIR"
cp source/INFO $BUILD_DIR
cp source/CREDITS $BUILD_DIR
cp source/LICENSE $BUILD_DIR
cp source/PACKAGE_ICON.PNG $BUILD_DIR
cp source/PACKAGE_ICON_256.PNG $BUILD_DIR
cp -r source/WIZARD_UIFILES $BUILD_DIR/WIZARD_UIFILES
cp -r source/scripts $BUILD_DIR/scripts
cp -r source/bin $BUILD_DIR/bin
mkdir -p $BUILD_DIR/conf

chmod +x -R $BUILD_DIR/bin
chmod +x -R $BUILD_DIR/scripts

echo
echo "*** Create $BUILD_DIR/package.tgz"
tar -C source -zcvf $BUILD_DIR/package.tgz bin
echo
echo "*** Create $PACKAGE_NAME.spk"
tar -C $BUILD_DIR -zcvf $OUTPUT_DIR/$PACKAGE_NAME.spk package.tgz INFO CREDITS LICENSE PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG scripts conf WIZARD_UIFILES
chmod 666 $OUTPUT_DIR/$PACKAGE_NAME.spk
rm -rf $BUILD_DIR
echo
echo "*** $PACKAGE_NAME.spk created"
