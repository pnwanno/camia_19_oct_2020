import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../globals.dart' as globals;
import '../dbs.dart';
import './readMagazine.dart';

class CitiMag extends StatefulWidget{
  _CitiMag createState(){
    return _CitiMag();
  }
}

class _CitiMag extends State<CitiMag>{
  DBTables _dbTables=DBTables();
  Directory _appDir;
  Directory _magDir;
  Directory _coverPages;
  Directory _innerPages;

  @override
  void initState() {
    initDir();
    super.initState();
  }//route's init state

  bool _unbookedAttended=false;
  deleteUnBookmarkedInnerPages()async{
    _unbookedAttended=true;
    Database _con= await _dbTables.citiMag();
    List _result=await _con.rawQuery("select * from magazines where bookmarked='no'");
    int _kount= _result.length;
    for(int _k=0; _k<_kount; _k++){
      int _pageCount= int.tryParse(_result[_k]["pages"]);
      String _pserverPath= _result[_k]["page_path"];
      List<String> _brkPath= _pserverPath.split("/");
      String _foldername= _brkPath[_brkPath.length - 2];
      for(int _j=0; _j<_pageCount; _j++){
        File _targF=File(_magDir.path + "/inner_pages/$_foldername-page${_j+1}.jpg");
        _targF.exists().then((_pageExists) {
          if(_pageExists)_targF.delete();
        });
      }
    }
  }

  initDir()async{
    _appDir= await getApplicationDocumentsDirectory();
    _magDir=Directory(_appDir.path + "/magazine");
    await _magDir.create();
    _coverPages= Directory(_magDir.path + "/cover_pages");
    await _coverPages.create();
    _innerPages=Directory(_magDir.path + "/inner_pages");
    await _innerPages.create();
    fetchLocal(refresh: true);
    if(_unbookedAttended == false){
      deleteUnBookmarkedInnerPages();
    }
  }//init dir

  List _globalPageData=List();
  fetchLocal({bool refresh})async{
    Database _con= await _dbTables.citiMag();
    var _result= await _con.rawQuery("select * from magazines where status='complete' order by cast(time_str as signed) desc");
    if(_result.length>0){
      _globalPageData=_result;
      if(!_pageDataAvailableNotifier.isClosed){
        _pageDataAvailableNotifier.add("kjut");
      }
    }

    if(refresh){
      updateLocal();
    }
  }//fetch local

  updateLocal()async{
    try{
      http.Response _resp= await http.post(
          globals.globBaseUrl2 + "?process_as=fetch_magazines"
      );
      if(_resp.statusCode == 200){
        Database _con= await _dbTables.citiMag();

        List<String> _localIds= List<String>();
        var _result= await _con.rawQuery("select mag_id from magazines where status='complete'");
        int _locCount= _result.length;
        for(int _k=0; _k<_locCount; _k++){
          _localIds.add(_result[_k]["mag_id"]);
        }
        var _serverObj= jsonDecode(_resp.body);
        int _remoteCount=_serverObj.length;
        for(int _k=0; _k<_remoteCount; _k++){
          String _targId= _serverObj[_k]["id"];
          if(_localIds.indexOf(_targId)<0){
            String _bookmarked="no"; String _magid=_serverObj[_k]["id"];
            String _ar=_serverObj[_k]["ar"];
            String _curStatus='pending'; String _coverPageServerPath=_serverObj[_k]["cover_page"];
            String _timeStr=_serverObj[_k]["time_str"];
            File _coverPageFile= File(_coverPages.path + "/$_magid.jpg");
            _coverPageFile.exists().then((_fexist) {
              if(!_fexist){
                http.readBytes(_coverPageServerPath).then((Uint8List _fbyte){
                  _coverPageFile.writeAsBytes(_fbyte).then((value){
                    _con.execute("insert into magazines (title, about, period, bookmarked, mag_id, pages, status, page_path, ar, pages_dl, time_str) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [
                      _serverObj[_k]["title"],
                      _serverObj[_k]["about"],
                      _serverObj[_k]["period"],
                      _bookmarked, _magid,_serverObj[_k]["pages"],
                      _curStatus, _coverPageServerPath, _ar, _curStatus, _timeStr]).then((value){
                        fetchMagazinePages(_magid);
                      fetchLocal(refresh: false);
                    });
                  });
                });
              }
            });
          }
        }
      }
    }
    catch(ex){
      showToast(
        text: "Offline mode",
        persistDur: Duration(seconds: 3)
      );
    }
  }//update local

  fetchMagazinePages(String _magId)async{
    //let's fetch the inner pages of the magazine if they do not exist
    Database _con= await _dbTables.citiMag();
    var _result= await _con.rawQuery("select * from magazines where mag_id='$_magId'");
    if(_result.length == 1){
      String _allPagesDL=_result[0]["pages_dl"];
      try{
        if(_allPagesDL == "pending"){
          int _pageLen=int.tryParse(_result[0]["pages"]);
          String _serverPagePath= _result[0]["page_path"].toString();
          List<String> _brkServerPagePath= _serverPagePath.split("/");
          int _pathLen= _brkServerPagePath.length;
          String _pageFolder= _brkServerPagePath[_pathLen - 2];
          String _rootServerPath= _serverPagePath.replaceFirst("$_pageFolder/page1.jpg", "");
          List<String> _savedPages= List<String>();
          for(int _k=0; _k<_pageLen; _k++){
            String _targPageStr="page${_k + 1}.jpg";
            File _targPageF= File(_innerPages.path + "/$_pageFolder-$_targPageStr");
            _targPageF.exists().then((bool _fexists){
              if(_fexists){
                _savedPages.add("$_pageFolder-$_targPageStr");
                if(_savedPages.length == _pageLen){
                  _con.execute("update magazines set status='complete' where mag_id='$_magId'");
                }
              }
              else{
                http.readBytes(
                    _rootServerPath + "$_pageFolder/$_targPageStr"
                ).then((_fetchedBytes){
                  _targPageF.writeAsBytes(_fetchedBytes).then((value){
                    _savedPages.add("$_pageFolder-$_targPageStr");
                    if(_savedPages.length == _pageLen){
                      _con.execute("update magazines set status='complete' where mag_id='$_magId'");
                    }
                  });
                });
              }
            });
          }
        }
      }
      catch(ex){

      }
    }
  }//fetch magazine pages

  animateToPage({String magId, String magTitle}){
    http.post(
        globals.globBaseUrl2 + "?process_as=record_read_magazine",
        body: {
          "user_id": globals.userId,
          "mag_id": magId
        }
    );

    Navigator.of(_pageContext).push(
      MaterialPageRoute(
          builder: (BuildContext _ctx){
            return ReadMagazine(magId, magTitle);
          }
      )
    );
  }//open page


  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize= MediaQuery.of(_pageContext).size;
    _toastTop= _screenSize.height * .6;

    return WillPopScope(
      child: Scaffold(
        backgroundColor: Colors.blue,
        body: FocusScope(
          child: Container(
            decoration: BoxDecoration(
              color: Color.fromRGBO(70, 50, 90, 1)
            ),
            child: Stack(
              children: [
                Container(
                  width: _screenSize.width,
                  height: _screenSize.height,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(180, 80, 150, .8)
                        ),
                      ),
                      Container(
                        width: _screenSize.width,
                        padding: EdgeInsets.only(left: 32, right: 18, top: 12, bottom: 14),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(120, 80, 150, 1),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14)
                          )
                        ),
                        child: Text(
                          "LW Citizen Magazine",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "ubuntu",
                            fontSize: 20,
                            color: Colors.white
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.only(top: 7),
                          child: StreamBuilder(
                            stream: _pageDataAvailableNotifier.stream,
                            builder: (BuildContext _ctx, AsyncSnapshot _pageshot){
                              if(_globalPageData.length>0){
                                return ListView.builder(
                                  padding: EdgeInsets.only(top: 0),
                                  itemCount: _globalPageData.length,
                                  physics: BouncingScrollPhysics(),
                                    itemBuilder: (BuildContext _ctx, int _itemIndex){
                                      if(_itemIndex % 2 == 0){
                                        List<Widget> _rowChildren= List<Widget>();
                                        for(int _k=0; _k<2; _k++){
                                          int _currentCount=_itemIndex + _k;
                                          if(_globalPageData.length> _currentCount){
                                            Map _blockData= _globalPageData[_currentCount];
                                            double _targAR=double.tryParse(_blockData["ar"]);
                                            double _targWidth= (_screenSize.width/2) - 9;
                                            double _targHeight= _targWidth/_targAR;
                                            String _targPath=_coverPages.path + "/" + _blockData["mag_id"] + ".jpg";
                                            _rowChildren.add(
                                              Opacity(
                                                opacity: .9,
                                                child: Container(
                                                  width: _targWidth,
                                                  height: _targHeight,
                                                  child: Stack(
                                                    overflow: Overflow.visible,
                                                    children: [
                                                      Container(
                                                        width:_targWidth,
                                                        height: _targHeight,
                                                        decoration: BoxDecoration(
                                                            image: DecorationImage(
                                                                image: FileImage(File(_targPath)),
                                                                fit: BoxFit.cover
                                                            ),
                                                          borderRadius: BorderRadius.circular(9)
                                                        ),
                                                      ),
                                                      Positioned(
                                                        left: 1,
                                                        bottom: 1,
                                                        child: _blockData["bookmarked"] == "yes" ? Container(
                                                          child: Icon(
                                                            FlutterIcons.tag_heart_mco,
                                                            color: Colors.white.withOpacity(.7),
                                                          ),
                                                        ): Container(),
                                                      ),
                                                      Positioned.fill(
                                                          child: Container(
                                                            child: Material(
                                                              color: Colors.transparent,
                                                              child: InkWell(
                                                                splashColor: Colors.purple.withOpacity(.5),
                                                                onTap: (){
                                                                  animateToPage(magId: _blockData["mag_id"], magTitle: _blockData["title"]);
                                                                },
                                                                child: Container(

                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              )
                                            );
                                          }
                                        }
                                        return Container(
                                          padding: EdgeInsets.only(right: 6,top: 3, bottom: 3, left: 6),
                                          decoration: BoxDecoration(
                                            color: Color.fromRGBO(120, 80, 150, .2)
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: _rowChildren,
                                          ),
                                        );
                                      }
                                      else return Container();
                                    }
                                );
                              }
                              return Container(
                                width: _screenSize.width,
                                height: _screenSize.height,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(120, 100, 150, .9)
                                ),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color.fromRGBO(245, 240, 240, 1)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                StreamBuilder(
                  stream: _toastCtr.stream,
                  builder: (BuildContext _ctx, _snapshot){
                    if(_showToast){
                      return AnimatedPositioned(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        left: 0, top: _toastTop,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            width: _screenSize.width,
                            alignment: Alignment.center,
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(
                                  begin: 0, end: 1
                              ),
                              duration: Duration(milliseconds: 700),
                              curve: Curves.easeInOut,
                              builder: (BuildContext _ctx, double _twVal, _){
                                return Opacity(
                                  opacity: _twVal < 0 ? 0 : _twVal>1?1: _twVal,
                                  child: Container(
                                    width: (_twVal * _screenSize.width) - 96<0 ? 0 : _twVal>1 ? 1 : (_twVal * _screenSize.width) - 96,
                                    padding: EdgeInsets.only(left: 16, right: 16, top: 9, bottom: 9),
                                    decoration: BoxDecoration(
                                        color: Color.fromRGBO(30, 30, 30, 1),
                                        borderRadius: BorderRadius.circular(16)
                                    ),
                                    child: Container(

                                      child: Text(
                                        _twVal < .7 ? "" : _toastText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: (_twVal * 13) + 1
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }
                    return Container();
                  },
                ),//local toast displayer
              ],
            ),
          ),
        ),
      ),
      onWillPop: () async{
        Navigator.pop(_pageContext);
        return false;
      },
    );
  }//route's build method

  bool _showToast=false;
  String _toastText="";
  double _toastTop=0;
  StreamController _toastCtr= StreamController.broadcast();
  showToast({String text, Duration persistDur}){
    _toastText=text;
    _showToast=true;
    _toastCtr.add("kjut");
    Future.delayed(
        persistDur,
            (){
          setState(() {
            _showToast=false;
            if(!_toastCtr.isClosed){
              _toastCtr.add("kjut");
            }
          });
        }
    );
  }

  StreamController _pageDataAvailableNotifier= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _toastCtr.close();
    _pageDataAvailableNotifier.close();
  }//dispose
}