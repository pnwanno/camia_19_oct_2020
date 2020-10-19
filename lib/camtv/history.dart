import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_icons/flutter_icons.dart';

import './theme_data.dart' as pageTheme;
import '../globals.dart' as globals;
import './watch_video.dart';

class WatchHistory extends StatefulWidget{
  _WatchHistory createState(){
    return _WatchHistory();
  }
}

class _WatchHistory extends State<WatchHistory>{
  @override
  initState(){
    _pageData=List();
    fetchHistory();
    addLVEvents();
    super.initState();
  }//route's init state

  double _reloadHeight=50;
  double _mainLVLoaderTop=-50;
  bool _pointerDown=false;
  bool _shouldReloadMain=false;
  addLVEvents(){
    _mainLVCtr.addListener(() {
      //reload event for the comment list
      if(_mainLVCtr.position.pixels<0){
        _mainLVLoaderTop= (-1 * _mainLVCtr.position.pixels) - 25;
        if(_pointerDown == false && _mainLVLoaderTop>=_reloadHeight-3){
          //the -3 subtracted from the the reload height is just an allowance value to allow basic delay from the user
          _shouldReloadMain=true;
          //reload method goes here
          _pageData=List();
          fetchHistory();
          Future.delayed(
              Duration(seconds: 2),
                  (){
                _mainLVLoaderTop=-50;
                _shouldReloadMain=false;
                if(!_mainReloaderCtr.isClosed)_mainReloaderCtr.add("kjut");
              }
          );
        }
        if(!_mainReloaderCtr.isClosed)_mainReloaderCtr.add("kjut");
      }
      if(_showMenu){
        hideSideMenu();
      }

      if(!_fetchingHistory){
        if(_mainLVCtr.position.pixels > _mainLVCtr.position.maxScrollExtent - (_screenSize.height * 2)){
          fetchHistory();
        }
      }
    });
  }//add list view events

  List _pageData=List();
  bool _fetchingHistory=false;
  fetchHistory()async{
    if(_fetchingHistory ==false){
      _fetchingHistory=true;
      try{
        http.Response _resp=await http.post(
          globals.globBaseTVURL + "?process_as=fetch_watch_history",
          body: {
            "user_id": globals.userId,
            "start": _pageData.length.toString()
          }
        );
        if(_resp.statusCode == 200){
          List _respObj= jsonDecode(_resp.body);
          if(_respObj.length == 0 && _pageData.length == 0){
            _pageData.add({
              "nodata": "nohistory"
            });
            if(!_pageDataUpdateNotifier.isClosed){
              _pageDataUpdateNotifier.add("kjut");
            }
          }
          else{
            _pageData.addAll(_respObj);
            if(_respObj.length>0){
              _fetchingHistory=false;
              if(!_pageDataUpdateNotifier.isClosed){
                _pageDataUpdateNotifier.add("kjut");
              }
            }
          }
        }
      }
      catch(ex){
        _fetchingHistory=false;
        _pageData.add({
          "error": "network"
        });
        if(!_pageDataUpdateNotifier.isClosed){
          _pageDataUpdateNotifier.add("kjut");
        }
      }
    }
  }//fetch history

  GlobalKey<ScaffoldState> _scaffKey=GlobalKey<ScaffoldState>();
  GlobalKey _curOptKey;
  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme="";
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize=MediaQuery.of(_pageContext).size;
    return WillPopScope(
      child: Scaffold(
        key: _scaffKey,
        backgroundColor: pageTheme.bgColor,
        appBar: AppBar(
          backgroundColor: pageTheme.bgColorVar1,
          title: Text(
            "History",
            style: TextStyle(
              color: pageTheme.fontColor
            ),
          ),
          iconTheme: IconThemeData(
            color: pageTheme.profileIcons
          ),
        ),
        body: FocusScope(
          child: Listener(
            onPointerUp: (_){
              _pointerDown=false;
            },
            onPointerDown: (_){
              _pointerDown=true;
              if(_showMenu){
                Future.delayed(
                    Duration(milliseconds: 800),
                        (){
                      hideSideMenu();
                    }
                );
              }
            },
            child: Container(
              child: Stack(
                key: _stackKey,
                children: [
                  Container(
                    width: _screenSize.width,
                    height: _screenSize.height,
                    child: StreamBuilder(
                      stream: _pageDataUpdateNotifier.stream,
                      builder: (BuildContext _ctx, AsyncSnapshot _pageShot){
                        if(_pageData.length == 0){
                          return Container(
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(pageTheme.profileIcons),
                            ),
                          );
                        }
                        return Container(
                          child: ListView.builder(
                            controller: _mainLVCtr,
                              physics: BouncingScrollPhysics(),
                              itemCount: _pageData.length,
                              itemBuilder: (BuildContext _ctx, int _itemIndex){
                                Map _firstMap= _pageData[0];
                                if(_pageData.length == 1 && _firstMap.containsKey("error")){
                                  if(_firstMap["error"] == "network"){
                                    return Container(
                                      height: _screenSize.height,
                                      padding:EdgeInsets.only(left: 18, right:18),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            child: Icon(
                                              FlutterIcons.cloud_off_outline_mco,
                                              color: pageTheme.fontGrey,
                                              size: 36,
                                            ),
                                          ),
                                          Container(
                                              margin:EdgeInsets.only(top: 4),
                                              child: Text(
                                                globals.noInternet,
                                                style: TextStyle(
                                                    color: pageTheme.profileIcons
                                                ),
                                                textAlign: TextAlign.center,
                                              )
                                          )
                                        ],
                                      ),
                                    );
                                  }
                                }
                                else if(_pageData.length == 1 && _firstMap.containsKey("nodata")){
                                  if(_firstMap["nodata"] == "nohistory"){
                                    return Container(
                                      height: _screenSize.height,
                                      padding:EdgeInsets.only(left: 18, right:18),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            child: Icon(
                                              FlutterIcons.chart_multiline_mco,
                                              color: pageTheme.fontGrey,
                                              size: 36,
                                            ),
                                          ),
                                          Container(
                                              margin:EdgeInsets.only(top: 4),
                                              child: Text(
                                                "No recorded history",
                                                style: TextStyle(
                                                    color: pageTheme.profileIcons
                                                ),
                                                textAlign: TextAlign.center,
                                              )
                                          )
                                        ],
                                      ),
                                    );
                                  }
                                }
                                Map _blockData=_pageData[_itemIndex];
                                String _posterPath=_blockData["poster"];
                                double _ar= double.tryParse(_blockData["ar"]);
                                String _locPostID= _blockData["post_id"];
                                String _locChannelID= _blockData["channel_id"];
                                GlobalKey _locKey= GlobalKey();
                                GlobalKey _dismissKey= GlobalKey();
                                return Dismissible(
                                  child: StreamBuilder(
                                    stream: _dismissItemAniCtr.stream,
                                    builder: (BuildContext _ctx, AsyncSnapshot _dismissShot){
                                      return AnimatedContainer(
                                        transform: _curItemPostID == _locPostID ?
                                        Matrix4.translationValues(_screenSize.width, 0, 0)
                                        :Matrix4.translationValues(0, 0, 0),
                                        duration: Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        onEnd: (){
                                          if(_curItemPostID == _locPostID){
                                            removeSeenHistoryItem("menu_item");
                                          }
                                        },
                                        decoration: BoxDecoration(
                                            color: pageTheme.bgColorVar1
                                        ),
                                        margin: EdgeInsets.only(bottom: 1),
                                        padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                                        child: Stack(
                                          children: [
                                            Container(
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    child: Stack(
                                                      children: [
                                                        Container(
                                                          width: _screenSize.width * .45,
                                                          height: _screenSize.width * .45/_ar,
                                                          decoration: BoxDecoration(
                                                              image: DecorationImage(
                                                                  image: NetworkImage(_posterPath)
                                                              )
                                                          ),
                                                        ),
                                                        Positioned(
                                                          bottom: 3,
                                                          right: 9,
                                                          child: Container(
                                                            padding: EdgeInsets.only(left: 2, right: 2, top: 1,bottom: 1),
                                                            decoration: BoxDecoration(
                                                              color: Colors.black
                                                            ),
                                                            child: Text(
                                                              globals.convSecToHMS(int.tryParse(_blockData["post_duration"])),
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 11
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ),//poster
                                                  Expanded(
                                                    child: Container(
                                                      margin: EdgeInsets.only(left: 7),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Container(
                                                            margin:EdgeInsets.only(bottom: 5),
                                                            child: Text(
                                                              _blockData["title"],
                                                              maxLines: 3,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                  color: pageTheme.profileIcons,
                                                                  fontFamily: "ubuntu",
                                                                  fontSize: 16
                                                              ),
                                                            ),
                                                          ), //post title
                                                          Container(
                                                            margin: EdgeInsets.only(bottom: 5),
                                                            child: Text(
                                                              _blockData["channel_name"],
                                                              style: TextStyle(
                                                                  color: pageTheme.fontGrey,
                                                                  fontSize: 13
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),//channel name
                                                          Container(
                                                            child: Text(
                                                              "Seen " + _blockData["seen_time"],
                                                              style: TextStyle(
                                                                  color: pageTheme.fontGrey,
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.bold
                                                              ),
                                                            ),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  highlightColor: Colors.transparent,
                                                  onTap:(){
                                                    if(!_showMenu){
                                                      Navigator.push(_pageContext, MaterialPageRoute(
                                                          builder: (BuildContext _ctx){
                                                            return WatchVideo(_locPostID, _locChannelID);
                                                          }
                                                      ));
                                                    }
                                                  },
                                                  child: Ink(
                                                    width: _screenSize.width,

                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              key: _locKey,
                                              right:0,
                                              top:0,
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: (){
                                                    _curOptKey=_locKey;
                                                    _curItemPostID=_locPostID;
                                                    showSideOptMenu();
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.all(3),
                                                    child: Icon(
                                                      FlutterIcons.dots_vertical_mco,
                                                      color: pageTheme.profileIcons,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  key: _dismissKey,
                                  background: Container(
                                    color: Colors.orangeAccent,
                                    child: Flex(
                                      direction: Axis.horizontal,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          flex: 1,
                                          child: Container(
                                            padding: EdgeInsets.only(left: 24),
                                            child: Icon(
                                              FlutterIcons.delete_ant,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          flex: 1,
                                          child: Container(
                                            padding: EdgeInsets.only(right: 24),
                                            child: Icon(
                                              FlutterIcons.delete_ant,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  onDismissed: (_){
                                    _curItemPostID=_locPostID;
                                    removeSeenHistoryItem("");
                                  },
                                );
                              }
                          ),
                        );
                      },
                    ),
                  ),
                  StreamBuilder(
                    stream: _mainReloaderCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _loadShot){
                      return Positioned(
                        width: _screenSize.width,
                        top: _shouldReloadMain ? _reloadHeight : _mainLVLoaderTop,
                        child: Opacity(
                          opacity: 1,
                          child: Container(
                            alignment: Alignment.center,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: pageTheme.bgColor,
                                shape: BoxShape.circle,
                              ),
                              padding: EdgeInsets.all(5),
                              child: _shouldReloadMain ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
                                strokeWidth: 2,
                              ) : CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(pageTheme.fontColor),
                                strokeWidth: 2,
                                value: (_mainLVLoaderTop/_reloadHeight),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ), //reload cue control
                  StreamBuilder(
                    stream: _sideOptMenuCtr.stream,
                    builder: (BuildContext _ctx, AsyncSnapshot _sideMenuShot){
                      if(_showMenu==false){
                        return Positioned(
                          child: Container(),
                          left: 0,bottom: 0,
                        );
                      }
                      return Positioned(
                        right: _sideMenuRight,
                        top: _sideMenuTop,
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 300),
                          builder: (BuildContext _ctx, double _twval, _){
                            return Opacity(
                              opacity: _twval,
                              child: Container(
                                width: _twval * _sideMenuWidth,
                                height: _twval*_sideMenuHeight,
                                decoration: BoxDecoration(
                                  color: pageTheme.bgColorVar1,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey,
                                      blurRadius: 20,
                                      offset: Offset(1,1)
                                    )
                                  ]
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        width: _sideMenuWidth,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: (){
                                              _dismissItemAniCtr.add("kjut");
                                            },
                                            child: Ink(
                                              child: Container(
                                                padding: EdgeInsets.only(top: 12, bottom: 12, left: 16, right: 16),
                                                child: Text(
                                                    "Remove from history",
                                                    style: TextStyle(
                                                        color: pageTheme.profileIcons,
                                                      fontSize: 18
                                                    )
                                                )
                                              ),
                                            ),
                                          ),
                                        )
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ), //side menu
                ],
              ),
            ),
          ),
          autofocus: true,
          onFocusChange: (bool _isFocused){
            if(_isFocused){
              if(MediaQuery.of(_pageContext).platformBrightness == Brightness.light){
                _deviceTheme="light";
              }
              else{
                _deviceTheme="dark";
              }
              if(_deviceTheme!=pageTheme.deviceTheme){
                pageTheme.deviceTheme=_deviceTheme;
                pageTheme.updateTheme();
                setState(() {
                });
              }
            }
            else{
              if(_showMenu){
                hideSideMenu();
              }
            }
          },
        ),
      ),
      onWillPop: ()async{
        if(_showMenu){
          hideSideMenu();
        }
        else Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  double _sideMenuTop=0;
  double _sideMenuRight=-2000;

  bool _showMenu=false;
  double _sideMenuWidth=250;
  double _sideMenuHeight=45;
  GlobalKey _stackKey=GlobalKey();
  showSideOptMenu(){
    if(_showMenu){
      hideSideMenu();
    }
    else{
      if(_curOptKey!=null){
        if(_curOptKey.currentContext!=null && _stackKey.currentContext!=null){
          RenderBox _stackRB= _stackKey.currentContext.findRenderObject();
          Offset _stackOffset= _stackRB.localToGlobal(Offset.zero);

          RenderBox _rb= _curOptKey.currentContext.findRenderObject();
          Offset _optOffset= _rb.localToGlobal(Offset.zero);
          _showMenu=true;
          _sideMenuTop=_optOffset.dy - _stackOffset.dy;
          _sideMenuRight=_screenSize.width - _optOffset.dx - _stackOffset.dx - 32;
          if(!_sideOptMenuCtr.isClosed) _sideOptMenuCtr.add("kjut");
        }
      }
    }
  }//displays the side menu

  hideSideMenu(){
    _showMenu=false;
    if(!_sideOptMenuCtr.isClosed){
      _sideOptMenuCtr.add("kjut");
    }
  }//hides the side menu

  String _curItemPostID="";
  List _storePageData;
  removeSeenHistoryItem(String _caller){
    _storePageData=List();
    _storePageData.addAll(_pageData);
    _pageData.removeWhere((element){
      String _targPID=element["post_id"];
      return _curItemPostID == _targPID;
    });

    if(_caller == "menu_item"){
      hideSideMenu();
      if(!_pageDataUpdateNotifier.isClosed)_pageDataUpdateNotifier.add("kjut");
    }

    _scaffKey.currentState.showSnackBar(
        SnackBar(
          content: Container(
            child: Flex(
              direction: Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 2,
                  child: Container(
                    child: Text(
                      "History removed",
                      style: TextStyle(
                          fontSize: 18,
                          color: pageTheme.bgColor
                      ),
                    ),
                  ),
                ),
                Flexible(
                  flex: 1,
                  child: Container(
                    child: RaisedButton(
                      onPressed: (){
                        restoreHistoryItem();
                      },
                      child: Text(
                        "Undo",
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
          duration: Duration(seconds: 12),
        )
    );
    Future.delayed(
      Duration(seconds: 12),
        (){
        if(_historyRestored){
          _historyRestored=false;
          _curItemPostID="";
        }
        else{
          _historyRestored=false;
          //send request to server
          try{
            http.post(
              globals.globBaseTVURL + "?process_as=remove_tv_watch_history",
              body: {
                "user_id": globals.userId,
                "post_id" : _curItemPostID
              }
            ).then((value){
              _curItemPostID="";
            });
          }
          catch(ex){

          }
        }
        }
    );
  }//remove item from seen history

  bool _historyRestored=false;
  restoreHistoryItem(){
    _historyRestored=true;
    _pageData=List();
    _pageData.addAll(_storePageData);
    _curItemPostID="";
    _scaffKey.currentState.hideCurrentSnackBar();
    if(!_pageDataUpdateNotifier.isClosed)_pageDataUpdateNotifier.add("kjut");
  }

  StreamController _pageDataUpdateNotifier= StreamController.broadcast();
  ScrollController _mainLVCtr= ScrollController();
  StreamController _mainReloaderCtr= StreamController.broadcast();
  StreamController _sideOptMenuCtr= StreamController.broadcast();
  StreamController _dismissItemAniCtr= StreamController.broadcast();
  @override
  void dispose() {
    _pageDataUpdateNotifier.close();
    _mainLVCtr.dispose();
    _mainReloaderCtr.close();
    _sideOptMenuCtr.close();
    _dismissItemAniCtr.close();
    super.dispose();
  }//route's dispose method
}