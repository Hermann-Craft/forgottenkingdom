#!/bin/bash
love2dPath="./debug/love"
gameName="forgottenkingdom"
gameType="client"
gameVersion=0.0.1
shouldOverwrite=0

if [ $1 != "" ]; then
    gameVersion=$1
fi

if [ $2 != "" ]; then
    shouldOverwrite=$2
fi

if ! [ -d "./bin" ]; then
    mkdir ./bin
fi

plist="
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version="1.0">
<dict>
	<key>BuildMachineOSBuild</key>
	<string>21D49</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeExtensions</key>
			<array>
				<string>love</string>
			</array>
			<key>CFBundleTypeIconFile</key>
			<string>GameIcon</string>
			<key>CFBundleTypeName</key>
			<string>LÖVE Project</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Owner</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>org.love2d.love-game</string>
			</array>
			<key>LSTypeIsPackage</key>
			<integer>1</integer>
		</dict>
		<dict>
			<key>CFBundleTypeName</key>
			<string>Folder</string>
			<key>CFBundleTypeOSTypes</key>
			<array>
				<string>fold</string>
			</array>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>None</string>
		</dict>
		<dict>
			<key>CFBundleTypeIconFile</key>
			<string>Document</string>
			<key>CFBundleTypeName</key>
			<string>Document</string>
			<key>CFBundleTypeOSTypes</key>
			<array>
				<string>****</string>
			</array>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
		</dict>
	</array>
	<key>CFBundleExecutable</key>
	<string>love</string>
	<key>CFBundleIconFile</key>
	<string>OS X AppIcon</string>
	<key>CFBundleIconName</key>
	<string>OS X AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>org.bawdeveloppement.${gameName}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${gameName}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>11.4a</string>
	<key>CFBundleSignature</key>
	<string>LoVe</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>DTCompiler</key>
	<string>com.apple.compilers.llvm.clang.1_0</string>
	<key>DTPlatformBuild</key>
	<string>13C100</string>
	<key>DTPlatformName</key>
	<string>macosx</string>
	<key>DTPlatformVersion</key>
	<string>12.1</string>
	<key>DTSDKBuild</key>
	<string>21C46</string>
	<key>DTSDKName</key>
	<string>macosx12.1</string>
	<key>DTXcode</key>
	<string>1321</string>
	<key>DTXcodeBuild</key>
	<string>13C100</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.games</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.7</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>© 2006-2022 LÖVE Development Team</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<false/>
</dict>
</plist>
"


function build {
    mkdir ./bin/v$gameVersion

    if [ -f "./bin/v$gameVersion/$gameName-$gameVersion.love" ]; then
        rm ./bin/v$gameVersion/$gameName-$gameVersion.love ./bin/v$gameVersion/$gameName-$gameVersion.AppImage
    fi

    if [ -f "./v$gameVersion.lua" ]; then
        mv main.lua old.lua
        mv v$gameVersion.lua main.lua  
    fi

    zip -9 -r ./bin/v$gameVersion/$gameName-$gameVersion.love ./src ./main.lua ./lib

    if [ -f "./old.lua" ]; then
        mv main.lua v$gameVersion.lua  
        mv old.lua main.lua
    fi

    # LINUX
    cat /usr/bin/love ./bin/v$gameVersion/$gameName-$gameVersion.love > ./bin/v$gameVersion/$gameName-$gameVersion.AppImage
    chmod a+x ./bin/v$gameVersion/$gameName-$gameVersion.AppImage

    # WIN 32
    cat $love2dPath-win32/love.exe ./bin/v$gameVersion/$gameName-$gameVersion.love > ./bin/v$gameVersion/$gameName-$gameVersion-win32.exe
    zip -9 -jr ./bin/v$gameVersion/$gameName-$gameVersion-win32.zip ./bin/v$gameVersion/$gameName-$gameVersion-win32.exe $love2dPath-win32/
    rm ./bin/v$gameVersion/$gameName-$gameVersion-win32.exe

    cat $love2dPath-win64/love.exe ./bin/v$gameVersion/$gameName-$gameVersion.love > ./bin/v$gameVersion/$gameName-$gameVersion-win64.exe
    zip -9 -jr ./bin/v$gameVersion/$gameName-$gameVersion-win64.zip ./bin/v$gameVersion/$gameName-$gameVersion-win64.exe $love2dPath-win64/
    rm ./bin/v$gameVersion/$gameName-$gameVersion-win64.exe

    # MAC OS X
    cp -r $love2dPath-mac/love.app ./bin/v$gameVersion/$gameName-$gameVersion.app
    cp  ./bin/v$gameVersion/$gameName-$gameVersion.love ./bin/v$gameVersion/$gameName-$gameVersion.app/Contents/Resources/
    echo "$plist" > ./bin/v$gameVersion/$gameName-$gameVersion.app/Contents/Info.plist
    cd ./bin/v$gameVersion/
    zip -9 -yr ./$gameName-$gameVersion-mac.zip ./$gameName-$gameVersion.app/
}

function clean_build {
    if [ -f "./bin/v$gameVersion/$gameName-$gameVersion-win32.exe" ]; then
        rm ./bin/v$gameVersion/$gameName-$gameVersion-win32.exe
    fi

    if [ -f "./bin/v$gameVersion/$gameName-$gameVersion-win32.zip" ]; then
        rm ./bin/v$gameVersion/$gameName-$gameVersion-win32.zip
    fi

    if [ -f "./bin/v$gameVersion/$gameName-$gameVersion-win64.exe" ]; then
        rm ./bin/v$gameVersion/$gameName-$gameVersion-win64.exe
    fi

    if [ -f "./bin/v$gameVersion/$gameName-$gameVersion-win64.zip" ]; then
        rm ./bin/v$gameVersion/$gameName-$gameVersion-win64.zip
    fi
}

if [ -d "./bin/v$gameVersion" ]; then
    if [ $shouldOverwrite == 1 ]; then
        clean_build
        build
    else
        echo "The build $gameVersion already exist."
        echo "Pass in command line : ./build.sh v$gameVersion 1 to overwrite"
    fi
else
    build
fi