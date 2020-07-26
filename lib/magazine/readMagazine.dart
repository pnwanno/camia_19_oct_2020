import 'dart:async';
import 'dart:io';

import 'package:camia/dbs.dart';
import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:liquid_progress_indicator/liquid_progress_indicator.dart';

import '../globals.dart' as globals;
class ReadMagazine extends StatefulWidget{
  _ReadMagazine createState(){
    return _ReadMagazine();
  }
  final String magazineId;
  final String magazineTitle;
  ReadMagazine(this.magazineId, this.magazineTitle);
}


class _ReadMagazine extends State<ReadMagazine>{
  globals.KjToast _kjToast;
  initState(){
    super.initState();
    initDir();
  }//route's init state

  DBTables _dbTables=DBTables();
  Directory _appDir;
  Directory _magDir;
  Directory _innerPages;
  initDir()async{
    _appDir= await getApplicationDocumentsDirectory();
    _magDir= Directory(_appDir.path + "/magazine");
    _innerPages= Directory(_magDir.path + "/inner_pages");
    await _innerPages.create();
    fetchPages();
  }//init dir

  fetchPages()async{
    try{
      Database _con= await _dbTables.citiMag();
      var _result= await _con.rawQuery("select * from magazines where mag_id=?", [widget.magazineId]);
      if(_result.length==1){
        int _pageLen=int.tryParse(_result[0]["pages"]);
        String _serverPagePath= _result[0]["page_path"].toString();
        double _magAR= double.tryParse(_result[0]["ar"]);
        List<String> _brkServerPagePath= _serverPagePath.split("/");
        int _pathLen= _brkServerPagePath.length;
        String _pageFolder= _brkServerPagePath[_pathLen - 2];
        String _rootServerPath= _serverPagePath.replaceFirst("$_pageFolder/page1.jpg", "");
        for(int _k=0; _k<_pageLen; _k++) {
          _magPages.add(Container());
          String _targPageStr="page${_k + 1}.jpg";
          File _tmpFile= File(_innerPages.path + "/$_pageFolder-$_targPageStr");
          _tmpFile.exists().then((_fexists){
            if(_fexists){
              if(_magPages.length == 0){
                _pageBusyOpacity=0;
                _pageBusyCtr.add("kjut");
              }
              _magPages.insert(_k, Container(
                width: _screenSize.width,
                child: Container(
                  height: _screenSize.width * (1/_magAR),
                  width: _screenSize.width,
                  decoration: BoxDecoration(
                      image: DecorationImage(
                          image: FileImage(_tmpFile),
                          fit: BoxFit.fill,
                          alignment: Alignment.topCenter
                      )
                  ),
                ),
              ));
              _magPages.removeAt(_k+1);
              _pageAvailableNotifier.add("kjut");
            }
            else{
              http.readBytes(_rootServerPath + "$_pageFolder/$_targPageStr").then((_fetchedByte){
                _tmpFile.writeAsBytes(_fetchedByte).then((value) {
                  _magPages.insert(_k, Container(
                    width: _screenSize.width,
                    alignment: Alignment.center,
                    child: Container(
                      height: _screenSize.width * _magAR,
                      width: _screenSize.width,
                      decoration: BoxDecoration(
                          image: DecorationImage(
                              image: FileImage(_tmpFile),
                              fit: BoxFit.fill,
                              alignment: Alignment.topCenter
                          )
                      ),
                    ),
                  ));
                  _magPages.removeAt(_k+1);
                  _pageAvailableNotifier.add("kjut");
                  if(_magPages.length == 0){
                    _pageBusyOpacity=0;
                    _pageBusyCtr.add("kjut");
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
  }//fetch pages

  List<Container> _magPages= List<Container>();
  StreamController _pageAvailableNotifier= StreamController.broadcast();

  double _pageBusyOpacity=1;
  double _pageBusyAmount=.5;
  String _pageBusyText="Loading ...";
  double _pageBusyAnimationEndVal=0;
  bool _bookmarked=false;
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize=MediaQuery.of(_pageContext).size;
    if(_kjToast == null){
      _kjToast= globals.KjToast(12.0, _screenSize, _toastCtr, _screenSize.height * .4);
    }
    return WillPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.magazineTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
            ),
          ),
        ),

        body: FocusScope(
          child: Container(
            child: Stack(
              overflow: Overflow.visible,
              children: <Widget>[
                Container(
                  height: _screenSize.height,
                  child: ListView(
                    children: <Widget>[
                      Container(
                        padding:EdgeInsets.only(top: 12),
                        child: StreamBuilder(
                          stream: _pageAvailableNotifier.stream,
                          builder: (BuildContext _ctx, _snapshot){
                            if(_magPages.length>0){
                              return Container(
                                child: LiquidSwipe(pages: _magPages),
                              );
                            }
                            else return Container();
                          },
                        ),
                      )//the inner pages display
                    ],
                  ),
                ),
                _kjToast,
                Positioned(
                  bottom: _screenSize.height * .25, left: 0,
                  child: IgnorePointer(
                    ignoring: true,
                    child: StreamBuilder(
                      stream: _pageBusyCtr.stream,
                      builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                        return AnimatedOpacity(
                          opacity: _pageBusyOpacity,
                          duration: Duration(milliseconds: 300),
                          child: StreamBuilder(
                            stream: _pageBusyFloatingCtr.stream,
                            builder: (BuildContext __ctx, __snapshot){
                              return TweenAnimationBuilder(
                                onEnd: (){
                                  if(_pageBusyAnimationEndVal == 0)
                                    _pageBusyAnimationEndVal=-12;
                                  else _pageBusyAnimationEndVal=0;
                                  _pageBusyFloatingCtr.add("kjut");
                                },
                                tween: Tween<double>(
                                    begin: -12, end: _pageBusyAnimationEndVal
                                ),
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                                builder: (BuildContext ___ctx, double _curVal, _){
                                  return Container(
                                    width: _screenSize.width, height: 111,
                                    alignment: Alignment.center,
                                    transform: Matrix4.translationValues(0, _curVal, 0),
                                    child: Stack(
                                      children: <Widget>[
                                        Container(
                                          alignment: Alignment.center,
                                          width: 120, height: 111,
                                          child: LiquidCustomProgressIndicator(
                                            direction: Axis.vertical,
                                            shapePath: globals.logoPath(Size(120, 111)),
                                            value: _pageBusyAmount,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 46, left: 30,
                                          child: Container(
                                            width: 55, height: 42,
                                            decoration: BoxDecoration(
                                                image: DecorationImage(
                                                    image: AssetImage("./images/citi_mag.png"),
                                                    fit: BoxFit.contain
                                                )
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 30, left: 22,
                                          child: Text(
                                            _pageBusyText,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontFamily: "ubuntu"
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),//page busy cue
              ],
            ),
          ),
          onFocusChange: (bool _isFocused){
          },
        ),
        ),
      onWillPop: ()async{
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

  StreamController _pageBusyCtr= StreamController.broadcast();
  StreamController _pageBusyFloatingCtr= StreamController.broadcast();
  StreamController _toastCtr= StreamController.broadcast();
  @override
  void dispose() {
    super.dispose();
    _toastCtr.close();
    _pageBusyCtr.close();
    _pageBusyFloatingCtr.close();
    _pageAvailableNotifier.close();
  }//route's dispose method
}