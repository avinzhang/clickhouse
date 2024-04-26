import json
import click


@click.command()
@click.option("-k", "--key", default="", help="Filter key. Default is none")
def query_log(key):
  text = input("Text: ")
  y = text.replace("'", "\"")
  res = json.loads(y)
  if key == '':
    for k,v in res.items():
      print(k, v)
  else:
    print(key, ": ", res[key])



if __name__ == "__main__":
    query_log()
