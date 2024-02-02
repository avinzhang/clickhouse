import xml.etree.ElementTree as ET
import os

import click

@click.command()
@click.option("-s", "--num_of_shards", default=1, help="Number of shards to create. Default is 1")
@click.option("-r", "--num_of_replicas", default=2, help="Number of replicas to create. Default is 2")


def create_configs(num_of_shards, num_of_replicas):
  cluster_name = 'cluster_'+ str(num_of_shards) + 'S_' + str(num_of_replicas) + 'R'
  num_of_nodes = num_of_shards * num_of_replicas
  node_id = 0
  while node_id < num_of_nodes:
    path = './config/clickhouse0' + str(node_id + 1)
    if not os.path.exists(path):
      os.mkdir(path)
    
    root = ET.Element('clickhouse')
    #Marcos
    mshard_id = node_id // num_of_replicas
    mreplica_id = node_id % num_of_replicas
    macro = ET.SubElement(root, 'macros')
    m_shard = ET.SubElement(macro, 'shard')
    m_shard.text = str(mshard_id)
    m_replica = ET.SubElement(macro, 'replica')
    m_replica.text = str(mreplica_id)

    #remote_servers
    shard_id = 1
    node = 1
    rs = ET.SubElement(root, 'remote_server')
    cluster = ET.SubElement(rs, cluster_name)
    while shard_id <= num_of_shards:
      shard = ET.SubElement(cluster, 'shard')
      internal_replication = ET.SubElement(shard, 'internal_replication')
      internal_replication.text = "true"
      replica_id = 0
      while replica_id < num_of_replicas:
        replica = ET.SubElement(shard, 'replica')
        host = ET.SubElement(replica, 'host')
        host.text = 'clickhouse0' + str(node)
        port = ET.SubElement(replica, 'port')
        port.text = '9000'
        replica_id+=1
        node+=1
      shard_id+=1

    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ", level=0)
    tree.write('./config/clickhouse0' + str(node_id + 1) + '/cluster.xml')
    node_id+=1  



if __name__ == '__main__':
  create_configs()
