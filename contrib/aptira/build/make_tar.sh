if [ ! -d stacktira ] ; then
    mkdir stacktira
else
    rm -rf stacktira/*
fi

cd stacktira
cp -r ../modules .
cp -r ../contrib .
cp -r ../data .

find . | grep .git | xargs rm -rf

cd ..

tar -cvf stacktira.tar stacktira
rm -rf stacktira
