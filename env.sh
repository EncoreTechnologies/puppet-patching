#!/bin/bash

if [ -f ~/.bashrc ]; then
  echo "Sourcing ~/.bashrc"
  source ~/.bashrc
elif [ -f ~/.bash_profile ]; then
  echo "Sourcing ~/.bash_profile"
  source ~/.bash_profile
else
  echo "NOT Sourcing ~/.bashrc OR ~/.bash_profile"
fi

"$@"
