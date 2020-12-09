#!/usr/bin/env python
# Copyright 2020 Encore Technologies
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import os
import sys
import requests
import socket
import datetime
import time
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'python_task_helper', 'files'))
from task_helper import TaskHelper

class PrometheusAlertSilence(TaskHelper):

    # This will be used with the silence duration to determine how many seconds to add to the UTC end time
    def get_offset(self, units):
        return {
            'minutes': 60,
            'hours': 3600,
            'days': 86400,
            'weeks': 604800
        }.get(units, 60)

    def get_end_timestamp(self, duration, units):
        offset = self.get_offset(units)
        return datetime.datetime.utcfromtimestamp(time.time() + duration*offset).isoformat()

    # Create a silence for every target that starts now and ends after the given duration
    def create_silences(self, targets, duration, units, prometheus_server):
        silence_ids = []
        for target in targets:
            payload = {
                'matchers': [
                    {'name': 'alias', 'value': target, 'isRegex': False}
                ],
                'startsAt': datetime.datetime.utcfromtimestamp(time.time()).isoformat(),
                'endsAt': self.get_end_timestamp(duration, units),
                'comment': "Silencing alerts on {} for patching".format(target),
                'createdBy': 'patching'
            }
            res = requests.post("http://{}:9093/api/v2/silences".format(prometheus_server), json=payload)
            res.raise_for_status()
            silence_ids.append(res.json()['silenceID'])

        return silence_ids

    # Remove all silences that were created by 'patching'
    def remove_silences(self, prometheus_server):
        res = requests.get("http://{}:9093/api/v2/silences".format(prometheus_server))
        res.raise_for_status()
        silences = res.json()

        for silence in silences:
            # Remove only silences that are active and were created by 'patching'
            if silence['status']['state'] == 'active' and silence['createdBy'] == 'patching':
                requests.delete("http://{}:9093/api/v2/silence/{}".format(prometheus_server, silence['id']))
                #print(silence['id'])

    # This function either creates a silence for each name in targets or deletes all silences
    # that were created by the 'patching' user
    def task(self, args):
        duration = args['silence_duration']
        units = args['silence_units']
        targets = args['targets']
        prometheus_server = args['prometheus_server']
        action = args['action']

        ends_at = self.get_end_timestamp(duration, units)

        if action == 'disable':
            self.create_silences(targets, duration, units, prometheus_server)

        elif action == 'enable':
            self.remove_silences(prometheus_server)

if __name__ == '__main__':
    PrometheusAlertSilence().run()
