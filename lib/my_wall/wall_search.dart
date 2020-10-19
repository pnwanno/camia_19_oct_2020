import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:http/http.dart' as http;

import '../globals.dart' as globals;
import './profile.dart';
import './wall_hash.dart';

class WallSearch extends StatefulWidget{
  _WallSearch createState(){
    return _WallSearch();
  }
}

class _WallSearch extends State<WallSearch> with SingleTickerProviderStateMixin{
  TabController _tabController;
  List<String> _tabStrings= ["Accounts", "Tags"];
  List<ScrollController> _scrollCtrs= [ScrollController(), ScrollController()];
  @override
  initState(){
    super.initState();
    _tabController= TabController(
      vsync: this,
      length: _tabStrings.length
    );
    _tabController.addListener(() {
      _curTab= _tabController.index;
      _tabChangeNotifier.add("kjut");
    });
    fetchHistory("accounts");
    fetchHistory("tags");

    _scrollCtrs.forEach((_sctr) {
      _sctr.addListener(() {
        if((_sctr.position.pixels > (_sctr.position.maxScrollExtent - _screenSize.height)) && _pageLoading[_curTab] == false){
          if(_curTab == 0){
            if (_accountResult.length>0 && _accountResult[_accountResult.length-1]["index"]!="-1"){
              _startPos[_curTab]=_accountResult[_accountResult.length-1]["index"];
              quickSearch(_curTab);
            }
          }
          else if(_curTab == 1){
            if (_tagResult.length>0 && _tagResult[_tagResult.length-1]["index"]!="-1"){
              _startPos[_curTab]=_tagResult[_tagResult.length-1]["index"];
              quickSearch(_curTab);
            }
          }
        }
      });
    });
  }//route's init state

  List _accountHistory= List();
  List _accountHistoryText= List();
  List _accountResult= List();
  List _tagResult= List();
  List _tagHistoryText= List();
  List _tagHistory= List();

  fetchHistory(String _section){
    try{
      http.post(
        globals.globBaseUrl + "?process_as=fetch_wall_search_history",
        body: {
          "user_id": globals.userId,
          "section": _section
        }
      ).then((_resp){
        if(_resp.statusCode == 200){
          try{
            List _respObj=jsonDecode(_resp.body);
            int _kount= _respObj.length;
            for (int _k=0; _k<_kount; _k++){
              if(_section == "accounts"){
                _accountHistoryText.add(_respObj[_k]["term"]);
                _accountHistory.add({
                  "username": _respObj[_k]["term"],
                  "time": _respObj[_k]["time"],
                  "dp": _respObj[_k]["dp"],
                  "fullname": _respObj[_k]["fullname"]
                });
                _accountResult.add({
                  "username": _respObj[_k]["term"],
                  "dp": _respObj[_k]["dp"],
                  "fullname": _respObj[_k]["fullname"],
                  "user_id": _respObj[_k]["user_id"]
                });
              }
              else if(_section == "tags"){
                _tagHistoryText.add(_respObj[_k]["term"]);
                _tagHistory.add({"term": _respObj[_k]["term"], "time": _respObj[_k]["time"]});
                _tagResult.add({"tag": _respObj[_k]["term"], "time": "", "count": ""});
              }

            }
            if(_section == "accounts"){
              _accountResult.add({"index": "-1"});
              _accountResultNotifier.add("kjut");
            }
            else{
              _tagResult.add({"index": "-1"});
              _tagResultNotifier.add("kjut");
            }
          }
          catch(ex){
          }
        }
      });
    }
    catch(ex){
    }
  }//fetch history

  List<bool> _pageLoading=[false, false];
  List<String> _startPos=["0", "0"];
  quickSearch(int _section, {bool resetStore})async{
    _pageLoading[_section]=true;
    try{
      http.Response _resp= await http.post(
        globals.globBaseUrl + "?process_as=search_wall",
        body: {
          "user_id": globals.userId,
          "section": _tabStrings[_section].toLowerCase(),
          "search_term" : _searchTxtCtr.text,
          "start": _startPos[_section]
        }
      );
      if(_resp.statusCode == 200){
        var _respObj= jsonDecode(_resp.body);
        if(_section == 0 && _respObj.length>0){
          if(resetStore) _accountResult= List();
          _accountResult.addAll(_respObj);
          _accountResultNotifier.add("kjut");
          _pageLoading[_section]=false;
        }
        else if(_section == 1){
          _tagResult= List();
          Map _hashes= _respObj["hash"];
          Map _hashtime= _respObj["time"];
          if(_hashes.length>0){
            _pageLoading[_section]=false;
            _hashes.forEach((key, value) {
              _tagResult.add({
                "tag": key,
                "count": value,
                "time":_hashtime[key]
              });
            });
            _tagResult.add({"index": _tagResult.length.toString()});
            _tagResultNotifier.add("kjut");
          }
        }
      }
    }
    catch(ex){
    }
  }//quick search

  saveSearchInHistory(String _section, String _searchterm)async{
    try{
      http.post(
        globals.globBaseUrl + "?process_as=save_wall_search_history",
        body: {
          "user_id": globals.userId,
          "section": _section,
          "term": _searchterm
        }
      );
    }
    catch(ex){

    }
  }//save search history

  StreamController _tabChangeNotifier= StreamController.broadcast();
  TextEditingController _searchTxtCtr= TextEditingController();
  int _curTab=0;
  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    return WillPopScope(
      child: Scaffold(
        backgroundColor: Color.fromRGBO(32, 32, 32, 1),
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(26, 26, 26, 1),
          title: StreamBuilder(
            stream: _tabChangeNotifier.stream,
            builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
              return Container(
                width: double.infinity,
                child: TextField(
                  autofocus: true,
                  style: TextStyle(
                    color: Colors.white
                  ),
                  controller: _searchTxtCtr,
                  decoration: InputDecoration(
                    hintText: "Search " + _tabStrings[_curTab].toLowerCase(),
                    hintStyle: TextStyle(
                      color: Colors.grey
                    ),
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none
                  ),
                  onChanged: (String _curval){
                    if(_curval.length>1){
                      quickSearch(_curTab, resetStore: true);
                    }
                  },
                ),
              );
            },
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Container(
                padding: EdgeInsets.only(top: 9, bottom: 9),
                child: Text(
                  _tabStrings[0]
                ),
              ),
              Container(
                padding: EdgeInsets.only(top: 9, bottom: 9),
                child: Text(
                    _tabStrings[1]
                ),
              )
            ],
            indicatorColor: Color.fromRGBO(50, 50, 50, 1),
            indicatorWeight: 1,
          ),
        ),
        body: FocusScope(
          child: Container(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  width: _screenSize.width, height: _screenSize.height,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Container(
                        width: _screenSize.width, height: _screenSize.height,
                        child: StreamBuilder(
                          stream: _accountResultNotifier.stream,
                          builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                            return ListView.builder(
                              controller: _scrollCtrs[0],
                              itemCount: _accountResult.length > 0 ? _accountResult.length - 1 : 0,
                                itemBuilder: (BuildContext _ctx, int _itemIndex){
                                String _targdp=_accountResult[_itemIndex]["dp"];
                                int _histIndex=_accountHistoryText.indexOf(_accountResult[_itemIndex]["username"]);
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Color.fromRGBO(24, 24, 24, 1)
                                    ),
                                    margin: EdgeInsets.only(bottom: 1),
                                    padding: EdgeInsets.only(top: 12, bottom: 12),
                                    child: ListTile(
                                      leading: Container(
                                        width: 50, height: 50,
                                        alignment: Alignment.center,
                                        child: _targdp.length == 1 ? CircleAvatar(
                                          radius: 24,
                                          child: Text(
                                            _targdp.toUpperCase()
                                          ),
                                        ): CircleAvatar(
                                          radius: 24,
                                          backgroundImage: NetworkImage(_targdp),
                                        ),
                                      ),//dp,
                                      title: Container(
                                        margin: EdgeInsets.only(left: 12, right: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin:EdgeInsets.only(bottom: 3),
                                              child: Text(
                                                _accountResult[_itemIndex]["username"],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontFamily: "ubuntu"
                                                ),
                                              ),
                                            ),//username
                                            Container(
                                              child: Text(
                                                _accountResult[_itemIndex]["fullname"],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white
                                                ),
                                              ),
                                            ),//fullname
                                          ],
                                        ),
                                      ),//username and fullname
                                      trailing: Container(
                                        width: 65,
                                        child:  _histIndex> -1 ? Container(
                                          child: Column(
                                            children: [
                                              Container(
                                                margin:EdgeInsets.only(bottom: 5),
                                                child: Icon(
                                                  FlutterIcons.history_oct,
                                                  color: Colors.grey,
                                                  size: 15,
                                                ),
                                              ),
                                              Container(
                                                child: Text(
                                                  _accountHistory[_histIndex]["time"],
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12
                                                  ),
                                                ),
                                              )
                                            ],
                                          )
                                        ): Container(),
                                      ),
                                      onTap: (){
                                        saveSearchInHistory("accounts", _accountResult[_itemIndex]["username"]);
                                        Navigator.of(_pageContext).push(MaterialPageRoute(
                                          builder: (BuildContext _ctx){
                                            return WallProfile(_accountResult[_itemIndex]["user_id"], username: _accountResult[_itemIndex]["username"],);
                                          }
                                        ));
                                      },
                                    ),
                                  );
                                }
                            );
                          },
                        ),
                      ),
                      Container(
                        width: _screenSize.width, height: _screenSize.height,
                        child: StreamBuilder(
                          stream: _tagResultNotifier.stream,
                          builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
                            return ListView.builder(
                              controller: _scrollCtrs[1],
                                itemCount: _tagResult.length > 0 ? _tagResult.length - 1 : 0,
                                itemBuilder: (BuildContext _ctx, int _itemIndex){
                                int _histIndex=_tagHistoryText.indexOf(_tagResult[_itemIndex]["tag"]);
                                  return Container(
                                    decoration: BoxDecoration(
                                        color: Color.fromRGBO(24, 24, 24, 1)
                                    ),
                                    margin: EdgeInsets.only(bottom: 1),
                                    padding: EdgeInsets.only(top: 12, bottom: 12),
                                    child: ListTile(
                                      leading: Container(
                                        width: 50, height: 50,
                                        alignment: Alignment.center,
                                        child: CircleAvatar(
                                          radius: 24,
                                          child: Text(
                                              "#"
                                          ),
                                        )
                                      ),//dp
                                      title: Container(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin:EdgeInsets.only(bottom: 3),
                                              child: Text(
                                                _tagResult[_itemIndex]["tag"],
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontFamily: "ubuntu"
                                                ),
                                              ),
                                            ),//tag
                                            Container(
                                              child: Row(
                                                children: [
                                                  Container(
                                                      child: Text(
                                              _tagResult[_itemIndex]["count"].toString() == "" ? "" :globals.convertToK(int.tryParse(_tagResult[_itemIndex]["count"].toString())) + " posts",
                                                        style: TextStyle(
                                                            color: Colors.white
                                                        ),
                                                      )
                                                  ),
                                                  Container(
                                                    width: 3, height: 3, margin:EdgeInsets.only(left: 7, right: 7),
                                                    decoration: BoxDecoration(
                                                      color: _histIndex <0 ? Colors.grey : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(7)
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Container(
                                                        child:Text(
                                                            _tagResult[_itemIndex]["time"],
                                                            overflow: TextOverflow.ellipsis,
                                                            maxLines: 2,
                                                            style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 13
                                                            )
                                                        )
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),//post count and time
                                          ],
                                        ),
                                      ),
                                      trailing: Container(
                                        width: 65,
                                        child: _histIndex> -1 ? Container(
                                          child: Column(
                                            children: [
                                              Container(
                                                margin:EdgeInsets.only(bottom: 3),
                                                child: Icon(
                                                  FlutterIcons.history_oct,
                                                  color: Colors.grey,
                                                  size: 15,
                                                ),
                                              ),
                                              Container(
                                                child: Text(
                                                  _tagHistory[_histIndex]["time"],
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                        ): Container(),
                                      ),
                                      onTap: (){
                                        saveSearchInHistory("tags", _tagResult[_itemIndex]["tag"]);
                                        Navigator.of(_pageContext).push(MaterialPageRoute(
                                            builder: (BuildContext _ctx){
                                              return WallHashTags(_tagResult[_itemIndex]["tag"].toString().replaceAll("#", ""));
                                            }
                                        ));
                                      },
                                    ),
                                  );
                                }
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      onWillPop: ()async{
        //Navigator.pop(_pageContext);
        return true;
      },
    );
  }//route's build method

  StreamController _accountResultNotifier= StreamController.broadcast();
  StreamController _tagResultNotifier= StreamController.broadcast();

  @override
  void dispose() {
    _searchTxtCtr.dispose();
    _tabChangeNotifier.close();
    _tabController.dispose();
    _accountResultNotifier.close();
    _tagResultNotifier.close();
    _scrollCtrs.forEach((element) {
      element.dispose();
    });
    super.dispose();
  }//route's dispose method
}