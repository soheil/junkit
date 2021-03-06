git clone -b GIT_BRANCH GIT_REMOTE_ORIGIN .

export RAILS_ENV=test
export GEM_PATH=./vendor/bundle
export GEMFILE_SHA_CALCULATED="$(shasum Gemfile | cut -f1 -d' ')"
export GEMS_TAR_FILE=/tmp/"$GEMFILE_SHA_CALCULATED"_gems.tar.gz

rm -rf /tmp/junkit
mkdir -p /tmp/junkit
cp config/*.yml /tmp/junkit
find config -name '*.yml.example' | sed "p;s/.example//" | xargs -n2 cp
cp /tmp/junkit/* config/

cat config/database.yml | sed 's/\(database: *\)\(.*\)/\1 JOB_NAME_\2/g' > /tmp/database.yml
mv /tmp/database.yml config/database.yml

cat config/tire.yml | sed 's/test_/JOB_NAME_test_/g' > /tmp/tire.yml
mv /tmp/tire.yml config/tire.yml

if [ -f "$GEMS_TAR_FILE" ]
then mkdir "$GEM_PATH"
  cd "$GEM_PATH"
  tar -zxvf $GEMS_TAR_FILE > /dev/null
  cd -
  bundle --deployment
else bundle --deployment
  echo 'bundle installed'
  echo 'saving gems for next time'
  cd "$GEM_PATH"
  tar -zcvf $GEMS_TAR_FILE .
  cd -
  echo 'gems updated'
  cd /tmp
  tarballCount=$(ls -lt | grep _gems.tar.gz | wc -l | sed 's/ //g')
  test $tarballCount -gt 10 && ls -t | grep _gems.tar.gz | tail -n$(($tarballCount - 10)) | xargs rm
  cd -
fi

[ -d "coverage" ] && rm -rf coverage
mkdir coverage

USE_PARALLEL="$(grep parallel_tests Gemfile)"

if [ -n "$USE_PARALLEL" ]
then bundle exec rake parallel:create --trace
  bundle exec rake parallel:load_schema
else bundle exec rake db:create --trace
  bundle exec rake db:schema:load --trace
fi

if [ -n "SINGLE_SPEC" ]
then bundle exec rspec "SINGLE_SPEC"
else if [ -n "$USE_PARALLEL" ]
  then bundle exec rake parallel:spec --trace
  else bundle exec rake spec:run_once --trace
  fi
fi

if [ -n "$USE_PARALLEL" ]
then bundle exec rake parallel:drop --trace
else bundle exec rake db:drop --trace
fi
