import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../dbs.dart';
import './search_result.dart';

class SearchHistory extends StatefulWidget{
  _SearchHistory createState(){
    return _SearchHistory();
  }
}

class _SearchHistory extends State<SearchHistory>{
  DBTables _dbTables= DBTables();
  @override
  void initState() {
    super.initState();
  }//route's init state

  Future<Widget> fetchLocalHistory()async{
    Database _con= await _dbTables.lwDict();
    var _result= await _con.rawQuery("select * from search_history order by cast(time_str as signed) desc");
    int _count=_result.length;
    return ListView.builder(
      itemCount: _count,
        itemBuilder: (BuildContext _ctx, int _itemIndex){
         return Container(
           padding: EdgeInsets.only(top: 12, bottom: 12, left: 12, right: 12),
           margin: EdgeInsets.only(bottom: 12),
           decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(12),
             color: Color.fromRGBO(246, 246, 246, 1)
           ),
           child: ListTile(
             onTap: (){
               Navigator.of(_pageContext).push(MaterialPageRoute(
                 builder: (BuildContext _ctx){
                   return DictSearchResult(_result[_itemIndex]["title"], calledFrom: "recent",);
                 }
               ));
             },
             title: Text(
               _result[_itemIndex]["title"],
             ),
           ),
         );
        }
    );
  }

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext=context;
    _screenSize= MediaQuery.of(_pageContext).size;
    return Scaffold(
      backgroundColor: Color.fromRGBO(230, 230, 230, 1),
      body: Container(
        padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 16),
        height: _screenSize.height, width: _screenSize.width,
        alignment: Alignment.center,
        child: FutureBuilder(
          future: fetchLocalHistory(),
          builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
            if(_snapshot.hasData){
              return _snapshot.data;
            }
            else{
              return CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }//route's build method
}