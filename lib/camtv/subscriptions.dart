import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../globals.dart' as globals;
import 'theme_data.dart' as pageTheme;

class SubscribedChannels extends StatefulWidget{
  _SubscribedChannels createState(){
    return _SubscribedChannels();
  }
}

class _SubscribedChannels extends State<SubscribedChannels>{

  @override
  void initState() {
    _channels=List();
    fetchChannelStamp();
    initLVEvents();
    super.initState();
  }//route's init state method

  List _channels= List();
  StreamController _channelStampAvailNotifier= StreamController.broadcast();
  bool _fetchingChannelStamp=false;
  fetchChannelStamp()async{
    if(_fetchingChannelStamp==false){
      _fetchingChannelStamp=true;
      try{
        http.Response _resp= await http.post(
            globals.globBaseTVURL + "?process_as=fetch_subbed_channels",
            body: {
              "user_id": globals.userId,
              "start": _channels.length.toString()
            }
        );
        if(_resp.statusCode == 200){
          List _respObj= jsonDecode(_resp.body);
          if(_respObj.length>0){
            _fetchingChannelStamp=false;
          }
          if(_channels.length == 0 && _respObj.length == 0){
            _channels.add({
              "nodata": "nodata"
            });
            if(!_channelStampAvailNotifier.isClosed)_channelStampAvailNotifier.add("kjut");
          }
          else{
            _channels.addAll(_respObj);
            if(!_channelStampAvailNotifier.isClosed)_channelStampAvailNotifier.add("kjut");
          }
        }
      }
      catch(ex){
        _channels.add({
          "error": "nointernet"
        });
        _fetchingChannelStamp=false;
        if(!_channelStampAvailNotifier.isClosed)_channelStampAvailNotifier.add("kjut");
      }
    }
  }

  ScrollController _channelStampScrollCtr= ScrollController();
  initLVEvents(){

  }//initializes the list view events

  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme="";
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize=MediaQuery.of(_pageContext).size;

    return WillPopScope(
      child: Scaffold(
        backgroundColor: pageTheme.bgColor,
        appBar: AppBar(
          backgroundColor: pageTheme.bgColorVar1,
          title: Text(
            "Channel Subscriptions",
            style: TextStyle(
              color: pageTheme.fontColor
            ),
          ),
          iconTheme: IconThemeData(
            color: pageTheme.fontColor
          ),
        ),
        body: FocusScope(
          child: Container(
            child: Stack(
              children: [
                Container(
                  width: _screenSize.width,
                  height: _screenSize.height,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: pageTheme.bgColorVar1
                        ),
                        margin: EdgeInsets.only(bottom: 1),
                        width: _screenSize.width,
                        height: 100,
                        padding: EdgeInsets.only(left: 16, right: 16),
                        child: StreamBuilder(
                          stream: _channelStampAvailNotifier.stream,
                          builder: (BuildContext _ctx, AsyncSnapshot _chStampShot){
                            if(_channels.length == 0){
                              return Container(
                                width: _screenSize.width - 32,
                                alignment: Alignment.centerLeft,
                                height: 100,
                                padding: EdgeInsets.only(left: 12),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(pageTheme.profileIcons),
                                  ),
                                ),
                              );
                            }
                            else{
                              Map _firstMap=_channels[0];
                              if(_firstMap.containsKey("error")){
                                return Container(
                                  width: _screenSize.width,
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.only(left: 32, right: 32),
                                  child: Text(
                                    globals.noInternet,
                                    style: TextStyle(
                                      color: pageTheme.fontGrey
                                    ),
                                  ),
                                );
                              }
                              else if(_firstMap.containsKey("nodata")){
                                return Container(
                                  width: _screenSize.width - 32,
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.only(left: 12, right: 12),
                                  child: Text(
                                    "You have not subscribed to any channels yet",
                                    style: TextStyle(
                                        color: pageTheme.fontGrey
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                width: _screenSize.width - 32,
                                padding: EdgeInsets.only(top: 12, bottom: 12,),
                                height: 100,
                                child: ListView.builder(
                                  itemCount: _channels.length,
                                  physics: BouncingScrollPhysics(),
                                  controller: _channelStampScrollCtr,
                                  scrollDirection: Axis.horizontal,
                                  itemBuilder: (BuildContext _ctx, int _itemIndex){
                                    Map _blockMap= _channels[_itemIndex];
                                    String _dpPath=_blockMap["dp"];
                                    String _newVid= _blockMap["not_seen_vid"];
                                    return Container(
                                      margin: EdgeInsets.only(right: 12),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            child: Stack(
                                              children: [
                                                Container(
                                                  child: _dpPath.length == 1 ?
                                                  CircleAvatar(
                                                    radius:28.5,
                                                    child: Text(
                                                      _dpPath.toUpperCase(),
                                                      style: TextStyle(
                                                        color: pageTheme.profileIcons
                                                      ),
                                                    ),
                                                    backgroundColor: pageTheme.bgColor,
                                                  ) : CircleAvatar(
                                                    radius: 28.5,
                                                    backgroundImage: NetworkImage(_dpPath),
                                                  ),
                                                ),
                                                _newVid=="yes" ? Positioned(
                                                  left:46,
                                                  top:45,
                                                  child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue,
                                                      shape: BoxShape.circle
                                                    ),
                                                  ),
                                                ):Container(),
                                                Positioned.fill(
                                                    child: Container(
                                                      child: Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          highlightColor: Colors.transparent,
                                                          onTap:(){
                                                            
                                                          },
                                                          child: Ink(

                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                )
                                              ],
                                            ),
                                          ),//dp
                                          Container(
                                            child: Text(
                                              _blockMap["channel_name"],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: pageTheme.fontGrey
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      )
                    ],
                  ),
                )
              ],
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
          },
        ),
      ),
      onWillPop: ()async{
        Navigator.pop(_pageContext);
        return false;
      },
    );
  }//route's build method

  @override
  void dispose() {
    _channelStampAvailNotifier.close();
    _channelStampScrollCtr.dispose();
    super.dispose();
  }//route's dispose method

}