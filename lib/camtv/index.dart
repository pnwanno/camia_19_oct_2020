import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camia/camtv/my_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:circular_clip_route/circular_clip_route.dart';

import '../globals.dart' as globals;
import '../dbs.dart';

class CamTV extends StatefulWidget{

  _CamTV createState(){
    return _CamTV();
  }
}

class _CamTV extends State<CamTV>{

  Directory _appDir;
  Directory _tvDir;
  DBTables _dbTables= DBTables();

  Widget _channeldp=Container();
  String _globalChannelName="";
  String _globalChannelId="";
  globals.KjToast _kjToast;
  @override
  void initState() {
    super.initState();
    initDir();
  }//route's init state

  ///A convenient function to get channel dp
  genChannelDp(String dp) async{
    Database _con=await _dbTables.tvProfile();
    var _result= await _con.rawQuery("select * from profile limit 1");
    if(_result.length == 1){
      _globalChannelName= _result[0]["channel_name"];
      _globalChannelId=_result[0]["channel_id"];
    }
    if(dp.length == 1){
      _channeldp= Container(
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 24,
          child: Text(
            dp
          ),
        ),
      );
    }
    else{
      _channeldp= Container(
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 24,
          backgroundImage: FileImage(File(_tvDir.path + "/$dp")),
        ),
      );
    }
    _pageLoadedCtr.add("kjut");
  }

  initDir()async{
    if(_appDir==null){
      _appDir= await getApplicationDocumentsDirectory();
      _tvDir= Directory(_appDir.path + "/camtv");
      await _tvDir.create();
    }

    Database _con= await _dbTables.tvProfile();
    var _result= await _con.rawQuery("select * from profile limit 1");
    if(_result.length<1){
      List _nameBrk=globals.fullname.split(" ");
      String _innerchname= _nameBrk[0] + " TV";
      String _inchDP=_innerchname.substring(0,1);
      String _inwebsite="";
      String _inbrief="";
      String _instatus="INACTIVE";
      String _inchannelid="";
      _con.execute("insert into profile (channel_name, dp, website, brief, status, channel_id) values (?, ?, ?, ?, ?, ?)", [_innerchname,_inchDP, _inwebsite, _inbrief, _instatus, _inchannelid]).then((value){
        channelInit(_innerchname, _inchannelid);
        genChannelDp(_inchDP);
      });
    }
    else{
      var _rw= _result[0];
      if(_rw["status"] == "INACTIVE"){
        channelInit(_rw["channel_name"], "");
      }
      else{
        String _inchdp= _rw["dp"];
        genChannelDp(_inchdp);
      }
    }
  }//init directory

  ///Tries to register this channnel if it has not been registered before
  Future channelInit(String channelName, String channelId)async{
    try{
      http.post(
        globals.globBaseUrl + "?process_as=try_create_tv_channel",
        body: {
          "user_id": globals.userId,
          "channel_name" : channelName,
          "channel_id": channelId
        }
      ).then((_resp) async{
        if(_resp.statusCode == 200){
          var _respObj= jsonDecode(_resp.body);
          if(_respObj["status"] == "success"){
            if(_respObj["type"] == "new"){
              Database _con= await _dbTables.tvProfile();
              String _newStatus="ACTIVE";
              String _newchid= _respObj["channel_id"];
              _con.execute("update profile set channel_id=?, status=?", [_newchid, _newStatus]);
            }
            else if(_respObj["type"] == "exists"){
              String _chname= _respObj["channel_name"];
              String _chdp= _respObj["dp"];
              if(_chdp.length >1){
                String _tmpDP= "$_chdp";
                List _brkD= _tmpDP.split("/");
                _chdp=_brkD.last;
                http.get(_tmpDP).then((__resp){
                  File _dpF= File(_tvDir.path + "/" + _chdp);
                  _dpF.writeAsBytes(__resp.bodyBytes).then((_newdpf){
                    genChannelDp(_chdp);
                  });
                });
              }
              else{
                genChannelDp(_chdp);
              }
              Database _con= await _dbTables.tvProfile();
              String _chwebsite= _respObj["website"];
              String _chabout= _respObj["about"];
              String _newStatus="ACTIVE";
              String _chid=_respObj["channel_id"];
              _con.execute("update profile set channel_name=?, dp=?, website=?, brief=?, status=?, channel_id=?", [_chname, _chdp, _chwebsite, _chabout, _newStatus, _chid]);
            }
          }
        }
      });
    }
    catch(ex){

    }
  }

  bool _drawerIsOpen=false;
  GlobalKey<ScaffoldState> _scaffoldkey= GlobalKey<ScaffoldState>();
  final _yourChannelKey= GlobalKey();
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    if(_kjToast == null){
      _kjToast= globals.KjToast(12.0, _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return Scaffold(
      key: _scaffoldkey,
      drawer: Drawer(
        child: FocusScope(
          autofocus: true,
          child: Container(
            decoration: BoxDecoration(
                color: Color.fromRGBO(32, 32, 32, 1),
                border: Border(
                    right: BorderSide(
                        color: Color.fromRGBO(32, 32, 32, 1)
                    )
                )
            ),
            child: ListView(
              children: <Widget>[
                DrawerHeader(
                    margin: EdgeInsets.only(bottom: 0, top: 0),
                    decoration: BoxDecoration(
                        color: Color.fromRGBO(20, 20, 20, 1)
                    ),
                    child: Container(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          StreamBuilder(
                            stream: _pageLoadedCtr.stream,
                            builder: (BuildContext _ctx, AsyncSnapshot snapshot){
                              return _channeldp;
                            },
                          ),//user dp

                          Expanded(
                              child: Container(
                                margin: EdgeInsets.only(left:12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Container(
                                      margin:EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        globals.fullname,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    //fullname

                                    StreamBuilder(
                                      stream: _pageLoadedCtr.stream,
                                      builder: (BuildContext _ctx, snapshot){
                                        return Container(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: <Widget>[
                                              Container(
                                                margin:EdgeInsets.only(right:3),
                                                child: Text(
                                                  _globalChannelName,
                                                  style: TextStyle(
                                                      color: Colors.deepOrange,
                                                      fontSize: 11,
                                                      fontFamily: "ubuntu"
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                FlutterIcons.tv_fea,
                                                color: Colors.white,
                                              )
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  ],
                                ),
                              )
                          ),//other user details
                        ],
                      ),
                    )
                ),//drawer header

                Container(
                  decoration: BoxDecoration(
                      color: Color.fromRGBO(10, 10, 10, 1),
                      border: Border(
                          bottom: BorderSide(
                              color:Color.fromRGBO(20, 20, 20, 1)
                          )
                      )
                  ),
                  child: ListTile(
                    leading: Icon(
                      FlutterIcons.home_fea,
                      color: Colors.grey,
                    ),
                    title: Text(
                      "Home",
                      style: TextStyle(
                          color: Colors.white
                      ),
                    ),
                  ),
                ),//home
                Container(
                  decoration: BoxDecoration(
                      color: Color.fromRGBO(10, 10, 10, 1),
                      border: Border(
                          bottom: BorderSide(
                              color:Color.fromRGBO(20, 20, 20, 1)
                          )
                      )
                  ),
                  child: ListTile(
                    leading: Icon(
                      FlutterIcons.trending_up_fea,
                      color: Colors.grey,
                    ),
                    title: Text(
                      "Trending",
                      style: TextStyle(
                          color: Colors.white
                      ),
                    ),
                  ),
                ),//trending
                Container(
                  decoration: BoxDecoration(
                      color: Color.fromRGBO(10, 10, 10, 1),
                      border: Border(
                          bottom: BorderSide(
                              color:Color.fromRGBO(20, 20, 20, 1)
                          )
                      )
                  ),
                  child: ListTile(
                    leading: Icon(
                      FlutterIcons.hand_ent,
                      color: Colors.grey,
                    ),
                    title: Text(
                      "Subscriptions",
                      style: TextStyle(
                          color: Colors.white
                      ),
                    ),
                  ),
                ),//subscriptions
                Container(
                  margin: EdgeInsets.only(top:36, bottom: 12),
                  padding: EdgeInsets.only(left:12, right:12),
                  child: Text(
                    "Your Library",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                      color: Color.fromRGBO(10, 10, 10, 1),
                      border: Border(
                          bottom: BorderSide(
                              color:Color.fromRGBO(20, 20, 20, 1)
                          )
                      )
                  ),
                  child: ListTile(
                    leading: Icon(
                      FlutterIcons.like2_ant,
                      color: Colors.grey,
                    ),
                    title: Text(
                      "Liked Videos",
                      style: TextStyle(
                          color: Colors.white
                      ),
                    ),
                  ),
                ), //liked videos
                Container(
                  decoration: BoxDecoration(
                      color: Color.fromRGBO(10, 10, 10, 1),
                      border: Border(
                          bottom: BorderSide(
                              color:Color.fromRGBO(20, 20, 20, 1)
                          )
                      )
                  ),
                  child: ListTile(
                    leading: Icon(
                      FlutterIcons.history_faw,
                      color: Colors.grey,
                    ),
                    title: Text(
                      "History",
                      style: TextStyle(
                          color: Colors.white
                      ),
                    ),
                  ),
                ), //subscriptions

                Container(
                    key: _yourChannelKey,
                    margin: EdgeInsets.only(top:12, bottom:12),
                    padding: EdgeInsets.only(top:8, bottom: 8),
                    decoration: BoxDecoration(
                        color: Colors.orange,
                        border: Border(
                            bottom: BorderSide(
                                color:Color.fromRGBO(20, 20, 20, 1)
                            )
                        )
                    ),
                    child: ListTile(
                      onTap: (){
                        if(_globalChannelId == ""){
                          _kjToast.showToast(
                              text: "It seems like this channel have not been registered yet! - Connect to the internet to register it",
                              duration: Duration(seconds: 7)
                          );
                        }
                        else{
                          _drawerIsOpen=true;
                          Navigator.of(_pageContext).push(
                              CircularClipRoute(
                                expandFrom: _yourChannelKey.currentContext,
                                builder: (_){
                                  return MyChannels(_globalChannelId);
                                },
                                curve: Curves.easeInOut,
                                reverseCurve: Curves.easeInOut,
                              )
                          );
                        }
                      },
                      leading: Icon(
                        FlutterIcons.tv_fea,
                        color: Colors.black,
                      ),
                      title: Text(
                        "Your Channel",
                        style: TextStyle(
                            color: Colors.white
                        ),
                      ),
                    )
                )
              ],
            ),
          ),
          onFocusChange: (bool _isFocused){
            if(_isFocused && _drawerIsOpen){
              initDir();
              //close the drawer here: Navigator.pop(_pageContext);
            }
          },
        ),
      ),
      backgroundColor: Color.fromRGBO(32, 32, 32, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(20, 20, 20, 1),
        title: Container(
          child: Row(
            children: <Widget>[
              Container(
                height: 24, width: 70,
                decoration: BoxDecoration(
                    image: DecorationImage(
                        image: AssetImage("./images/camtv.png"),
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter
                    )
                ),
              ),
              Container(
                child: Text("Cam TV"),
              )
            ],
          ),
        ),
      ),

      body: FocusScope(
        child: Container(
          child: Stack(
            children: <Widget>[
              Container(),
              _kjToast
            ],
          ),
        ),
        autofocus: true,
        onFocusChange: (bool _isFocused){
          if(_isFocused){

          }
        },
      ),
    );
  }//route's build

  StreamController _pageLoadedCtr= StreamController.broadcast();
  StreamController _toastCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _pageLoadedCtr.close();
    pullRefreshCtr.close();
    _toastCtr.close();
  }//route's dispose

  ///This is the container placed as the first child of the listview
  ///to show a pull-to-refresh cue
  Widget pullToRefreshContainer(){
    return StreamBuilder(
      stream: pullRefreshCtr.stream,
      builder: (BuildContext ctx, AsyncSnapshot snapshot){
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: pullRefreshHeight,
          color: Color.fromRGBO(30, 30, 30, 1),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                  bottom: pullRefreshHeight - pullRefreshLoadHeight - 20,
                  child: Container(
                    alignment: Alignment.center,
                    child: Container(
                        width: 50, height: 50,
                        alignment: Alignment.center,
                        child: pullRefreshHeight< pullRefreshLoadHeight ?
                        CircularProgressIndicator(
                          value: pullRefreshHeight/pullRefreshLoadHeight,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          strokeWidth: 3,
                        ):
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          strokeWidth: 3,
                        )
                    ),
                  )
              )
            ],
          ),
        );
      },
    );
  }//pull to refresh container

  double pullRefreshHeight=0;
  double pullRefreshLoadHeight=80;
  StreamController pullRefreshCtr= StreamController.broadcast();
  ScrollController _globalListCtr= ScrollController();
  ///Pass a listview as child widget to this widget
  Widget kjPullToRefresh({Widget child}){
    return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (PointerUpEvent pue){
          if(pullRefreshHeight< pullRefreshLoadHeight){
            pullRefreshHeight =0;
            pullRefreshCtr.add("kjut");
          }
          else{
            Future.delayed(
                Duration(milliseconds: 1500),
                    (){
                  //call the refresh function
                  pullRefreshHeight=0;
                  pullRefreshCtr.add("kjut");

                }
            );
          }
        },
        onPointerMove: (PointerMoveEvent pme){
          Offset _delta= pme.delta;
          if(_globalListCtr.position.atEdge && !_delta.direction.isNegative){
            double dist= math.sqrt(_delta.distanceSquared);
            if(pullRefreshHeight <pullRefreshLoadHeight){
              pullRefreshHeight +=(dist/3);
              pullRefreshCtr.add("kjut");
            }
          }
        },
        child: child
    );
  }//kjut pull to refresh
}