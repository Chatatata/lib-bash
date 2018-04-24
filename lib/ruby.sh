#!/usr/bin/env bash

lib::ruby::gemfile-lock-version() {
  local gem=${1}

  if [[ ! -f Gemfile.lock ]]; then
    error "Can not find Gemfile.lock"
    return 1
  fi

  egrep " ${gem} \([0-9]" Gemfile.lock | sed -e 's/[\(\)]//g' | awk '{print $2}'
}

lib::ruby::bundler-version() {
  if [[ ! -f Gemfile.lock ]]; then
    error "Can not find Gemfile.lock"
    return 1
  fi
  tail -1 Gemfile.lock | sed 's/ //g'
}


#———————————————————————————————————————————————————————————————————————————————
# GEM dependencies
#———————————————————————————————————————————————————————————————————————————————
# This extracts a gem version from Gemfile.lock. If not found,
# default (argument) is used. This helps prevent version mismatch
# between the very few gem dependencies of the zeus subsystem, and Rails.
gem.version() {
  local gem=$1
  local default=$2
  local version

  if [[ -f './Gemfile.lock' ]]; then
    version=$(egrep "${gem} \(\d+\.\d+\.\d+\(\.\d+\)?\)" Gemfile.lock | awk '{print $2}' | sed 's/[()]//g')
  else
    gem.list.load
    version=$(gem list | egrep "${gem}" | awk '{print $2}' | sed -E 's/[()]//g')
  fi

  version=${version:-${default}} # fallback to the default if not found
  printf "%s" ${version}
}

gem.list.load() {
  if [[ ! -s "${GEM_LIST_FILE}" || -z $(find "${GEM_LIST_FILE}" -mmin -30) ]]; then
    gem list > "${GEM_LIST_FILE}"
  fi
}

gem.is_installed() {
  local gem=$1
  local version=$2

  gem.list.load

  if [[ -z ${version} ]]; then
    egrep "${gem} \(" "${GEM_LIST_FILE}"
  else
    egrep "${gem} \(" "${GEM_LIST_FILE}" | grep ${version}
  fi
}

# Install the gem, but use the version argument as a default. Final version
# is determined from Gemfile.lock using the +gem.version+ above.
gem.install() {
  local gem_name=$1
  local gem_version=$2
  gem_version=$(gem.version ${gem_name} ${gem_version})
  if [[ -z $(gem.is_installed ${gem_name} ${gem_version}) ]]; then
    printf "(${txtylw}installing${clr}) ... ${bldred}"
    gem install ${gem_name} --version ${gem_version} 1>/dev/null
    result=$?
    printf ${clr}
    [[ $result == 0 ]] && printf "${bldgrn} ✔ ${clr}\n"
    [[ $result != 0 ]] && printf "${bldred} FAILED ${clr} with code ${result}\n"
    [[ $result != 0 ]] && {
      [[ ${_is_sourced} == "no" ]] && exit 1
      [[ ${_is_sourced} == "no" ]] || return
    }
    rbenv rehash >/dev/null
  else
    printf "${bldgrn} ✔ ${clr} (already installed)\n"
  fi
}
