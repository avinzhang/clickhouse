import xml.etree.ElementTree as ET
import os
import yaml
import click


def create_keeper_config(num_of_keepers):
  keeper_id = 0
  while keeper_id < num_of_keepers:
    path = './config/keeper0' + str(keeper_id + 1)
    if not os.path.exists(path):
      os.mkdir(path)

    tree = ET.parse('./config/keeper.xml')
    root = tree.getroot()
    kname = root.find("keeper_server/server_id")
    kname.text = str(keeper_id + 1)

    server_id = 0
    raft_config = root.find("keeper_server/raft_configuration")
    while server_id < num_of_keepers:
      server = ET.SubElement(raft_config, 'server')
      s_id = ET.SubElement(server, 'id')
      s_id.text = str(server_id + 1)
      hostname = ET.SubElement(server, 'hostname')
      hostname.text = 'keeper0' + str(server_id + 1)
      port = ET.SubElement(server, 'port')
      port.text = str(9234)
      server_id+=1


    tree = ET.ElementTree(root)
    ET.indent(tree, space="    ", level=0)
    tree.write('./config/keeper0' + str(keeper_id + 1) + '/keeper.xml')
    keeper_id+=1

def create_ch_config(num_of_shards, num_of_replicas):
  num_of_nodes = num_of_shards * num_of_replicas
  cluster_name = 'cluster_'+ str(num_of_shards) + 'S_' + str(num_of_replicas) + 'R'
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
    
    #remote_servers
    shard_id = 1
    node = 1
    rs = ET.SubElement(root, 'remote_servers')
    cluster = ET.SubElement(rs, cluster_name)
    while shard_id <= num_of_shards:
      shard = ET.SubElement(cluster, 'shard')
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

    #Macros
    mshard_id = node_id // num_of_replicas
    mreplica_id = node_id % num_of_replicas
    macro = ET.SubElement(root, 'macros')
    m_shard = ET.SubElement(macro, 'shard')
    m_shard.text = str(mshard_id)
    m_replica = ET.SubElement(macro, 'replica')
    m_replica.text = str(mreplica_id)

    tree = ET.ElementTree(root)
    ET.indent(tree, space="    ", level=0)
    tree.write('./config/clickhouse0' + str(node_id + 1) + '/config.xml')
    node_id+=1


def create_docker_compose(num_of_shards, num_of_replicas, num_of_keepers):
  with open(f'./templates/docker-compose.yml','r') as f: 
    data = yaml.safe_load(f)
  composefile = open('docker-compose.yml', 'w')
  s = "---\n"
  composefile.write(s)
  composefile.close()
  version_tmp = {'version': data['version']}
  with open(f'docker-compose.yml', 'a') as file:
      yaml.dump(version_tmp,file,sort_keys=False)
  network_tmp = {'networks': data['networks']}
  with open(f'docker-compose.yml', 'a') as file:
      yaml.dump(network_tmp,file,sort_keys=False)

  keeper_tmp = data['services']['keeper']
  services_all = {}
  for keeper_id in range(num_of_keepers):
    keeper_tmp['ports'] = ([str(9181 + keeper_id) +':9181'])
    keeper_tmp['hostname'] = 'keeper0'+str(keeper_id+1)
    keeper_tmp['container_name'] = 'keeper0'+str(keeper_id+1)
    volume_tmp = (['./config/keeper0'+str(keeper_id+1)+'/keeper.xml:/etc/clickhouse-keeper/keeper_config.xml',
    './log/keeper0'+str(keeper_id+1)+':/var/log/clickhouse-keeper',
    './data/keeper0'+str(keeper_id+1)+':/var/lib/clickhouse'])
    keeper_tmp['volumes'] = volume_tmp
    services_all['keeper0'+str(keeper_id+1)] = keeper_tmp
    with open(f'./templates/docker-compose.yml','r') as f:
      data = yaml.safe_load(f)
    keeper_tmp = data['services']['keeper']
    
  clickhouse_tmp = data['services']['clickhouse']
  for clickhouse_id in range(num_of_shards * num_of_replicas):
    clickhouse_tmp['ports'] = ([str(9001 + clickhouse_id) +':9000'])
    clickhouse_tmp['hostname'] = 'clickhouse0'+str(clickhouse_id+1)
    clickhouse_tmp['container_name'] = 'clickhouse0'+str(clickhouse_id+1)
    volume_tmp = (['./config/clickhouse0'+ str(clickhouse_id+1)+':/etc/clickhouse-server/config.d',
    './config/users.xml:/etc/clickhouse-server/users.d/users.xml',
    './data/clickhouse0'+str(clickhouse_id+1)+':/var/lib/clickhouse',
    './log/clickhouse0'+str(clickhouse_id+1)+':/var/log/clickhouse-server'])
    clickhouse_tmp['volumes'] = volume_tmp
    services_all['clickhouse0'+str(clickhouse_id+1)] = clickhouse_tmp
    with open(f'./templates/docker-compose.yml','r') as f:
      data = yaml.safe_load(f)
    clickhouse_tmp = data['services']['clickhouse']
  services_tmp = {'services': services_all}
  with open(f'docker-compose.yml', 'a') as f:
    yaml.dump(services_tmp,f,sort_keys=False)

    



@click.command()
@click.option("-s", "--num_of_shards", default=1, help="Number of shards to create. Default is 1")
@click.option("-r", "--num_of_replicas", default=2, help="Number of replicas to create. Default is 2")
@click.option("-k", "--num_of_keepers", default=3, help="Number of keepers to create. Default is 3")
def create_all_configs(num_of_shards, num_of_replicas, num_of_keepers):
  create_ch_config(num_of_shards, num_of_replicas)
  create_keeper_config(num_of_keepers)
  create_docker_compose(num_of_shards, num_of_replicas, num_of_keepers)
  

if __name__ == "__main__":
    create_all_configs()
