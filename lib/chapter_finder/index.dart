import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import './theme_data.dart' as pageTheme;
import './search.dart';
import './history.dart';

class ChapterFinder extends StatefulWidget{
  _ChapterFinder createState(){
    return _ChapterFinder();
  }
}

class _ChapterFinder extends State<ChapterFinder>{

  initState(){
    super.initState();
  }//route's init state method

  dispose(){
    super.dispose();
  }//route's dispose method

  BuildContext _pageContext;
  Size _screenSize;
  String _deviceTheme="";

  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: pageTheme.bgColorVar1,
        body: Listener(
          child: FocusScope(
            autofocus: true,
            child: Container(
              child: Stack(
                children: [
                  Container(
                    width: _screenSize.width,
                    height: _screenSize.height,
                    child: ListView(
                      children: [
                        Container(
                          padding: EdgeInsets.only(left: 9, right: 9),
                          margin: EdgeInsets.only(top: _screenSize.height * .15),
                          child: Column(
                            children: [
                              Hero(
                                tag: "finder_logo",
                                child: Container(
                                  margin: EdgeInsets.only(top: 7, bottom: 7),
                                  width: 150,
                                  height: 68,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: AssetImage("./images/chapter_finder.png")
                                      )
                                  ),
                                ),
                              ),//chapter finder logo
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: (){
                                    Navigator.of(_pageContext).push(
                                        MaterialPageRoute(
                                            builder: (BuildContext _ctx){
                                              return SearchChapter();
                                            }
                                        )
                                    );
                                  },
                                  highlightColor: Colors.transparent,
                                  child: Hero(
                                    child: Container(
                                      width: _screenSize.width - 36,
                                      margin: EdgeInsets.only(left: 9, top: 12),
                                      decoration: BoxDecoration(
                                          color: pageTheme.bgColor,
                                          borderRadius: BorderRadius.circular(28),
                                          border: Border.all(
                                              color: pageTheme.borderColor
                                          )
                                      ),
                                      child: Stack(
                                        children: [
                                          Container(
                                            padding:EdgeInsets.only(top: 14, bottom: 14, left: 48),
                                            child: Text(
                                              "Search for a chapter",
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 16,
                                                  fontStyle: FontStyle.italic
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 14,
                                            top: 12,
                                            child: Icon(
                                              FlutterIcons.search_location_faw5s,
                                              color: pageTheme.fontGrey,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    tag: "search_box",
                                  ),
                                ),
                              )//pseudo search box
                            ],
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(top: 9, left: 9, right: 9),
                          width: _screenSize.width - 18,
                          alignment: Alignment.center,
                          child: Text(
                            "A repository of the BLW Campus Ministry's Chapters",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: pageTheme.homeDescText,
                              fontFamily: "pacifico",
                              fontSize: 16
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),

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
        floatingActionButton: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: pageTheme.borderColor
              )
            )
          ),
          height: 60,
          padding: EdgeInsets.only(left: 12, right: 12, top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  highlightColor: Colors.transparent,
                  child: Container(
                    child: Column(
                      children: [
                        Container(
                          margin: EdgeInsets.only(bottom: 2),
                          child: Icon(
                            FlutterIcons.home_ant,
                            size: 20,
                            color: pageTheme.activeIcon,
                          ),
                        ),
                        Container(
                          child: Text(
                            "Home",
                            style: TextStyle(
                                color: pageTheme.activeIcon,
                                fontSize: 13
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),//home
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (){
                    Navigator.of(_pageContext).push(
                      MaterialPageRoute(
                        builder: (BuildContext _ctx){
                          return SearchChapter();
                        }
                      )
                    );
                  },
                  highlightColor: Colors.transparent,
                  child: Ink(
                    child: Container(
                      child: Column(
                        children: [
                          Container(
                            margin: EdgeInsets.only(bottom: 2),
                            child: Icon(
                              FlutterIcons.search1_ant,
                              color: pageTheme.fontColor2,
                              size: 20,
                            ),
                          ),
                          Container(
                            child: Text(
                              "Search",
                              style: TextStyle(
                                  color: pageTheme.fontColor2,
                                  fontSize: 13
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),//search
              Material(
                color: Colors.transparent,
                child: InkWell(
                  highlightColor: Colors.transparent,
                  onTap: (){
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (BuildContext _ctx){
                          return SearchHistory();
                        }
                      )
                    );
                  },
                  child: Ink(
                    child: Container(
                      child: Column(
                        children: [
                          Container(
                            margin: EdgeInsets.only(bottom: 2),
                            child: Icon(
                              FlutterIcons.history_mco,
                              size: 20,
                              color: pageTheme.fontColor2,
                            ),
                          ),
                          Container(
                            child: Text(
                              "History",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: pageTheme.fontColor2
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),//history
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
      onWillPop: ()async{
        Navigator.of(_pageContext).pop();
        return false;
      },
    );
  }//route's build method

}