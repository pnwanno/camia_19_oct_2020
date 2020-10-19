import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class TestVid extends StatefulWidget{
  _Testvid createState(){
    return _Testvid();
  }
}

class _Testvid extends State<TestVid>{
  String _baseURL="https://camia.blwcampusministry.com/testvids";
  Map<String, VideoPlayerController> _vplayers=Map<String, VideoPlayerController>();
  Map<String, GlobalKey> _liKeys= Map<String, GlobalKey>();
  Map<String, String> _playerIDMap= Map<String, String>();
  @override
  void initState() {
    super.initState();
    _lvctr.addListener(() {
      List<String> _curDisp= List<String>();
      _liKeys.forEach((key, value) {
        if(value.currentContext!=null){
          RenderBox _rb= value.currentContext.findRenderObject();
          Offset _targOffset= _rb.localToGlobal(Offset.zero);
          if(_targOffset.dy>0 && _targOffset.dy< _screenSize.height){
            _curDisp.add(key);
          }
        }
      });
      if(_curDisp.length>0){
        String _firstP= _curDisp[0];
        String _playerId=_playerIDMap[_firstP] + ".0";
        _vplayers.forEach((key, value) {
          if(key!=_playerId){
            if(value.value.isPlaying)value.pause();
          }
        });
        if(!_vplayers[_playerId].value.isPlaying){
          _vplayers[_playerId].play();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      //for(int _k=0;_k<13; _k++){
        //resetVids();
        //_dispCount++;
        //_pageCtr.add("event");
      //}
    });
  }//route's init state

  resetVids(){
    _vplayers.forEach((k,v){
      v.dispose();
    });
    _vplayers=Map<String, VideoPlayerController>();
    _playerIDMap=Map<String, String>();
  }

  resetVPs(){
    _vps.forEach((element) {
      element.dispose();
    });
    _vps=[];
    debugPrint("kjut reset vps");
  }

  int _dispCount=0;
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize=MediaQuery.of(_pageContext).size;
    return Scaffold(
      appBar: AppBar(
        actions: [
          RaisedButton(
            onPressed: (){
              if(_dispCount<13){
                resetVids();

                _dispCount++;
                _pageCtr.add("event");
              }
            },
            child: Text(
              "Press me"
            ),
          ),

          RaisedButton(
            onPressed: (){
              resetVPs();
              _dispCount=1;
              _pageCtr.add("event");
            },
            child: Text(
                "Press2"
            ),
          ),
          RaisedButton(
            onPressed: (){
              setState(() {

              });
            },
            child: Text(
                "Set state"
            ),
          )
        ],
      ),
      body: Container(
        child: StreamBuilder(
          stream: _pageCtr.stream,
          builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
            return ListView.builder(
                controller: _lvctr,
                itemCount: _dispCount,
                itemBuilder: (BuildContext _ctx, int _index){
                  String _liId="$_index";
                  if(!_liKeys.containsKey(_liId)){
                    _liKeys[_liId]= GlobalKey();
                  }
                  List<Widget> _pvchildren= List<Widget>();
                  if(!_playerIDMap.containsKey(_liId)){
                    _playerIDMap[_liId]= DateTime.now().millisecondsSinceEpoch.toString() + _index.toString();
                  }
                  resetVPs();
                  _vps.add(VideoPlayerController.network(_baseURL + "/mov" + (_index + 1).toString() + ".mp4"));
                  VideoPlayerController _focPlayer= _vps.last;
                  _focPlayer.initialize().then((value) {
                    _focPlayer.setLooping(true);
                    _focPlayer.play();
                    _focPlayer.addListener(() {
                      debugPrint(_focPlayer.value.position.inSeconds.toString());
                    });
                    _arn.add(_focPlayer.value.aspectRatio);
                  });
                  for(int _k=0; _k<1; _k++){
                    _pvchildren.add(
                        Container(
                          child: StreamBuilder(
                            stream: _arn.stream,
                            builder: (BuildContext ctx, AsyncSnapshot _sn){
                              if(_sn.hasData){
                                return AspectRatio(
                                  aspectRatio: _sn.data,
                                  child: VideoPlayer(
                                      _focPlayer
                                  ),
                                );
                              }
                              return Container();
                            },
                          ),
                        )
                    );
                  }
                  return Container(
                    key: _liKeys[_liId],
                    margin: EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        Container(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Text(
                              "Video $_index"
                          ),
                        ),
                        Container(
                          height: 250,
                          child: PageView(
                            children: _pvchildren,
                          ),
                        )
                      ],
                    ),
                  );
                }
            );
          },
        ),
      ),
    );
  }//route's build method

  ScrollController _lvctr= ScrollController();
  StreamController _pageCtr= StreamController.broadcast();

  saveBuild(){
    return ListView.builder(
        controller: _lvctr,
        itemCount: _dispCount,
        itemBuilder: (BuildContext _ctx, int _index){
          String _liId="$_index";
          if(!_liKeys.containsKey(_liId)){
            _liKeys[_liId]= GlobalKey();
          }
          List<Widget> _pvchildren= List<Widget>();
          if(!_playerIDMap.containsKey(_liId)){
            _playerIDMap[_liId]= DateTime.now().millisecondsSinceEpoch.toString() + _index.toString();
          }
          String _playerID= _playerIDMap[_liId];
          if(!_vplayers.containsKey(_playerID)){
            _vplayers["$_playerID.0"]=VideoPlayerController.network(
                _baseURL + "/mov" + (_index + 1).toString() + ".mp4"
            );
            _vplayers["$_playerID.0"].initialize().then((value) {
              _vplayers["$_playerID.0"].setVolume(1);
              //_vplayers["$_liId.0"].seekTo(Duration(milliseconds: 500));
              _vplayers["$_playerID.0"].setLooping(true);
            });
          }
          debugPrint("kjut player length is " + _vplayers.length.toString());
          _vplayers.forEach((key, value) {
            debugPrint("kjut player keys are $key");
          });
          for(int _k=0; _k<1; _k++){
            _pvchildren.add(
                Container(
                  child: AspectRatio(
                    aspectRatio: 16/9,
                    child: VideoPlayer(
                        _vplayers["$_playerID.0"]
                    ),
                  ),
                )
            );
          }
          return Container(
            key: _liKeys[_liId],
            margin: EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Text(
                      "Video $_index"
                  ),
                ),
                Container(
                  height: 250,
                  child: PageView(
                    children: _pvchildren,
                  ),
                )
              ],
            ),
          );
        }
    );
  }

  List<VideoPlayerController> _vps=[];
  StreamController _arn= StreamController.broadcast();
  @override
  void dispose() {
    _vplayers.forEach((key, value) {
      value.dispose();
    });
    _lvctr.dispose();
    _pageCtr.close();
    _vps.forEach((element) {
      element.dispose();
    });
    _arn.close();
    super.dispose();
  }//route's dispose method
}