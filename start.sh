#!/bin/bash
# author:jaywxl

# ------------ 配置 ----------------
cfhost="cf.jaywxl.eu.org"
homehost="home.jaywxl.eu.org"
ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])";
informlog="./informlog"

# CloudFlare账号配置
x_email="victor0907ai1019@gmail.com"
# --空间ID--
zone_id="8d863ce25963a36954bfe90f1c374d8b"
# --Global API Key--
api_key="1f4978b637781bfc090ae982013c43f75efe9"

#企业微信推送设置
# --企业ID--
CORPID="ww86317246d173f4bf"
# --应用ID--
SECRET="aQHCKSgBhPFNxsBcQWohfYuyqKYrjeBiehv4XlzJAH8"
# --agentid--
AGENTID="1000002"
# --成员ID--
# 设置需要推送给谁，不填写默认推送给全员
USERID="Jaywxl"


# ------------ 代码 ----------------
yanzheng(){

  # 清除$informlog
  rm $informlog

  # 验证cf账号信息是否正确
  res=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json");
  resSuccess=$(echo "$res" | jq -r ".success");
  if [[ $resSuccess != "true" ]]; then
    echo "登陆错误，请检查cloudflare账号信息填写是否正确!" >> $informlog
    exit 1;
  fi
    echo "Cloudflare账号验证成功";

  # 开始CloudFlare测速
  ./CloudflareST -tp 80 -dn 100 -url http://cdn.cloudflare.steamstatic.com/steam/apps/256843155/movie_max.mp4

}


update_domain(){

  ipAddr=$1
  uphost=$2
  
  # 开始DDNS
  if [[ $ipAddr =~ $ipv4Regex ]]; then
    recordType="A"
  else
    recordType="AAAA"
  fi

  listDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${recordType}&name=${uphost}"
  createDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"

  # 关闭小云朵
  proxy="false"

  res=$(curl -s -X GET "$listDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json")
  recordId=$(echo "$res" | jq -r ".result[0].id")
  recordIp=$(echo "$res" | jq -r ".result[0].content")

  if [[ $recordIp = "$ipAddr" ]]; then
    echo "更新失败，获取的IP与云端相同" >> $informlog
    resSuccess=false
  elif [[ $recordId = "null" ]]; then
    res=$(curl -s -X POST "$createDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$uphost\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
    resSuccess=$(echo "$res" | jq -r ".success")
  else
    updateDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${recordId}"
    res=$(curl -s -X PUT "$updateDnsApi"  -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$uphost\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
    resSuccess=$(echo "$res" | jq -r ".success")
  fi

  if [[ $resSuccess = "true" ]]; then
    echo "$uphost更新成功" >> $informlog
  else
    echo "$uphost更新失败" >> $informlog
  fi
}


push_wxcom(){

  message_text=$(echo "$(sed "$ ! s/$/\\\n/ " ./informlog | tr -d '\n')")
  wxapi="https://qyapi.weixin.qq.com"
  WX_tkURL="$wxapi/cgi-bin/gettoken"
  WXURL="$wxapi/cgi-bin/message/send?access_token="

  ##企业微信推送##
  #判断access_token是否过期
  if [ ! -f ".access_token" ]; then
    res=$(curl -X POST $WX_tkURL -H "Content-type:application/json" -d '{"corpid":"'$CORPID'", "corpsecret":"'$SECRET'"}')
    resSuccess=$(echo "$res" | jq -r ".errcode")
    if [[ $resSuccess = "0" ]]; then
      echo "access_token获取成功";
      echo '{"access_token":"'$(echo "$res" |  jq -r ".access_token")'", "expires":"'$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 7200))'"}' > .access_token
      CHECK="true"
    else
      echo "access_token获取失败，请检查CORPID和SECRET";
      CHECK="false"
    fi
  else
    if [[ $(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) -le $(cat .access_token | jq -r ".expires") ]]; then
      echo "企业微信access_token在有效期内";
      CHECK="true"
    else
      res=$(curl -X POST $WX_tkURL -H "Content-type:application/json" -d '{"corpid":"'$CORPID'", "corpsecret":"'$SECRET'"}')
      resSuccess=$(echo "$res" | jq -r ".errcode")
      if [[ $resSuccess = "0" ]]; then
        echo "access_token获取成功";
        echo '{"access_token":"'$(echo "$res" |  jq -r ".access_token")'", "expires":"'$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 7200))'"}' > .access_token
        CHECK="true"
      else
        echo "access_token获取失败，请检查CORPID和SECRET";
        CHECK="false"
      fi
    fi
  fi

  if [[ $CHECK != "true" ]]; then
    echo "access_token验证不正确"
  else
    access_token=$(cat .access_token | jq -r ".access_token")
    WXURL=$WXURL
    res=$(timeout 20s curl -X POST $WXURL$access_token -H "Content-type:application/json" -d '{"touser":"'$USERID'", "msgtype":"text", "agentid": "'$AGENTID'", "text":{"content":"'$message_text'"}}')
    if [ $? == 124 ];then
        echo '企业微信_api请求超时,请检查网络是否正常'
    fi
    resSuccess=$(echo "$res" | jq -r ".errcode")
    if [[ $resSuccess = "0" ]]; then
        echo "企业微信推送成功";
        elif [[ $resSuccess = "81013" ]]; then
        echo "企业微信USERID填写错误，请检查后重试";
        elif [[ $resSuccess = "60020" ]]; then
        echo "企业微信应用未配置本机IP地址，请在企业微信后台，添加IP白名单";
        else
        echo "企业微信推送失败，请检查企业微信参数是否填写正确";
    fi
  fi

}


yanzheng
# 获取优选后的ip地址
cfAddr=$(sed -n "$((x + 2)),1p" ./result.csv | awk -F, '{split($1, parts, ":"); print parts[1]}');
update_domain $cfAddr $cfhost
homeAddr=$(ifconfig pppoe-wan | grep inet6 | awk '{print$3}' | awk -F '/' '{print$1}' | head -n 1)
update_domain $homeAddr $homehost
push_wxcom

exit 0;
