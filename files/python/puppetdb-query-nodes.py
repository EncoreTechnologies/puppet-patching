#!/usr/bin/env python
import argparse
import json
import os
import requests
import socket

# The puppet server is expected to have the following alt name defined in its cert
PUPPETDB_SERVER='puppetdb'
PUPPETDB_PORT=8081
SSL_DIR='/etc/puppetlabs/puppet/ssl'
MONITORING_FACT='monitoring_enabled'

def parse_cli_args():
    parser = argparse.ArgumentParser(prog=os.path.basename(__file__))
    parser.add_argument('--server', default=PUPPETDB_SERVER)
    parser.add_argument('--port', default=PUPPETDB_PORT)
    parser.add_argument('--ssl-dir', default=SSL_DIR)
    parser.add_argument('--monitoring-fact', default=MONITORING_FACT)
    return parser.parse_args()


class PuppetDbPrometheusServiceDiscovery(object):

    # Save SSL and cert info in class variables for later use
    def __init__(self, certname=None,
                 ssl_dir=SSL_DIR,
                 server=PUPPETDB_SERVER,
                 port=PUPPETDB_PORT,
                 monitoring_fact=MONITORING_FACT):
        if not certname:
            certname = socket.gethostname()
        self.certname = certname
        self.ssl_key = '{}/private_keys/{}.pem'.format(ssl_dir, self.certname)
        self.ssl_cert = '{}/certs/{}.pem'.format(ssl_dir, self.certname)
        self.ssl_ca = '{}/certs/ca.pem'.format(ssl_dir)
        os.environ['REQUESTS_CA_BUNDLE'] = self.ssl_ca

        self.monitoring_fact = monitoring_fact

        self.puppetdb_server = server
        self.puppetdb_port = port

        self.session = requests.Session()
        self.session.verify = True
        self.session.cert = (self.ssl_cert, self.ssl_key)

    def run(self):
        query = self.puppetdb_query_exported_resources()
        puppetdb_response = self.puppetdb_query(query)
        prom_sc = self.transform_puppetdb_to_prom_scrape_config(puppetdb_response)
        print(json.dumps(prom_sc, indent=4, sort_keys=True))

    def puppetdb_query(self, q):
        url = "https://{}:{}/pdb/query/v4".format(self.puppetdb_server, self.puppetdb_port)
        resp = self.session.post(url, json={'query': q})
        resp.raise_for_status()
        return resp.json()

    def puppetdb_query_exported_resources(self):
        # This query first checks for any hosts that have a fact:
        #   monitoring_enabled = false
        #   mointoring_enabled = "false"
        #
        # If monitoring is disabled on a host using this fact, then it is excluded form the results, otherwise
        # it is included.
        #
        # Secondly we collect all of the "prometheus::scrape_job" exported resources and
        # use those to generate our targets to scrape.
        return 'resources { !(certname in facts[certname] { name = "' + self.monitoring_fact + '" and (value = "false" or value = false)  }) and type = "Prometheus::Scrape_job" and exported = true }'

    def transform_puppetdb_to_prom_scrape_config(self, puppetdb_response):
        sc_groups = {}
        for resp in puppetdb_response:
            targets = resp['parameters']['targets']
            labels = resp['parameters'].get('labels', {})
            labels['job'] = resp['parameters']['job_name']
            # dicts are not hashable, this makes it hashable
            labels_hashable = frozenset(labels.items())
            if labels_hashable not in  sc_groups:
                sc_groups[labels_hashable] = {
                    'labels': labels,
                    'targets': targets,
                }
            else:
                sc_groups[labels_hashable]['targets'].extend(targets)
        # get just the values of the aggregated groups
        return sc_groups.values()

if __name__ == "__main__":
    args = parse_cli_args()
    client = PuppetDbPrometheusServiceDiscovery(server=args.server, port=args.port, ssl_dir=args.ssl_dir,
                                                monitoring_fact=args.monitoring_fact)
    client.run()

