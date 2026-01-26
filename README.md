
`    ./README.md    `



###### удалить все (запускать от рута)

```sh


 docker stop $(docker ps -q) 2>/dev/null; docker rm $(docker ps -qa) 2>/dev/null; docker volume rm $(docker volume ls -q) 2>/dev/null; docker network rm $(docker network ls -q) 2>/dev/null; docker system prune -a --volumes -f


```

