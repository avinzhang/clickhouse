import xml.etree.ElementTree as ET
import os

import click

def create_cluster(shards, replicas):
  cluster_name = 'cluster_'+ str(shards) + 'S_' + str(replicas) + 'R'
  print(cluster_name)
  num_of_nodes = replicas * shards 
  node_id = 0
  while node_id < num_of_nodes:
    root = ET.Element('clickhouse')
    #Marcos
    mshard_id = node_id // replicas
    mreplica_id = node_id % replicas
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
    while shard_id <= shards:
      shard = ET.SubElement(cluster, 'shard')
      internal_replication = ET.SubElement(shard, 'internal_replication')
      internal_replication.text = "true"
      replica_id = 0
      while replica_id < replicas:
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

@click.command()
@click.option("-s", "--num_of_shards", default=1, help="Number of shards to create. Default is 1")
@click.option("-r", "--num_of_replicas", default=2, help="Number of replicas to create. Default is 2")
def create_config(num_of_shards, num_of_replicas):
  num_of_nodes = num_of_shards * num_of_replicas
  node_id = 0
  while node_id < num_of_nodes:  
    path = './config/clickhouse0' + str(node_id + 1)
    if not os.path.exists(path):
      os.mkdir(path)

    tree = ET.parse('./config/config.xml')
    root = tree.getroot()
    dname = root.find("display_name")
    dname.text = 'clickhouse0' + str(node_id + 1)
    httphost = root.find("interserver_http_host")
    httphost.text = 'clickhouse0' + str(node_id + 1)
    tree = ET.ElementTree(root)
    tree.write('./config/clickhouse0' + str(node_id + 1) + '/config.xml')
    node_id+=1
  create_cluster(num_of_shards, num_of_replicas)

def main():
  create_config()
  

if __name__ == "__main__":
    main()
