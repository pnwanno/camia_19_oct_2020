
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../dbs.dart';
import './search_result.dart';
import '../globals.dart' as globals;
class WOD extends StatefulWidget{
  _WOD createState(){
    return _WOD();
  }
}

class _WOD extends State<WOD>{
  double _gridMaxExtent;
  double _gridChildSpacing;
  DBTables _dbTables=DBTables();
  Future<Widget> fetchWOD()async{
    _gridMaxExtent=_screenSize.width< 750 ? _screenSize.width/2.2: _screenSize.width/4.2;
    _gridChildSpacing= _screenSize.width<750 ? (_screenSize.width/2)  - (_screenSize.width/2.2): (_screenSize.width/4) - (_screenSize.width/4.2);
    Database _con= await _dbTables.lwDict();
    var _result= await _con.rawQuery("select * from day_word order by id desc");
    int _count=_result.length;
    return GridView.builder(
      itemCount: _count,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _gridMaxExtent,
          crossAxisSpacing: _gridChildSpacing,
          mainAxisSpacing: 12
        ),
        itemBuilder: (BuildContext _ctx, int _itemIndex){
          return Container(
            padding: EdgeInsets.only(left: 12, right: 12, top: 16, bottom: 16),
            decoration: BoxDecoration(
                color: Color.fromRGBO(240, 240, 240, 1),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  offset: Offset(1,1),
                  color: Color.fromRGBO(220, 220, 220, 1),
                  blurRadius: 2,
                )
              ]
            ),
            child: GestureDetector(
              onTap: (){
                Navigator.of(_pageContext).push(MaterialPageRoute(
                  builder: (BuildContext _ctx){
                    return DictSearchResult(_result[_itemIndex]["title"], calledFrom: "wod",);
                  }
                ));
              },
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Container(
                      child: Text(
                        _result[_itemIndex]["title"],
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: "ubuntu",
                          color: Colors.blueGrey
                        ),
                      ),
                    ),
                    Container(
                      child: Text(
                          globals.kChangeCase(_result[_itemIndex]["definition"], globals.KWordcase.sentence_case),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18
                        ),
                      ),
                    ),
                    Container(
                      child: Text(
                        _result[_itemIndex]["day"],
                        style: TextStyle(
                          fontFamily: "ubuntu"
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }
    );
  }//fetch wod

  BuildContext _pageContext;
  Size _screenSize;
  @override
  Widget build(BuildContext context) {
    _pageContext= context;
    _screenSize= MediaQuery.of(_pageContext).size;

    return Scaffold(
      backgroundColor: Color.fromRGBO(230, 230, 230, 1),
      body: Container(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
        height: _screenSize.height, width: _screenSize.width,
        alignment: Alignment.center,
        child: FutureBuilder(
          future: fetchWOD(),
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