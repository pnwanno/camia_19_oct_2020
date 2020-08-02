import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../dbs.dart';

class AffirmationDetails extends StatefulWidget{
  _AffirmationDetails createState(){
    return _AffirmationDetails();
  }
  final affirmID;
  AffirmationDetails(this.affirmID);
}

class _AffirmationDetails extends State<AffirmationDetails>{
  DBTables _dbTables= DBTables();
  Future<Widget> getAffirmationDetails()async{
    Database _con= await _dbTables.lwDict();
    var _result= await _con.rawQuery("select * from affirmations where id=?", [widget.affirmID]);
    if(_result.length == 1){
      return ListView(
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Text(
              "Affirmations for " + _result[0]["day"],
              style: TextStyle(
                fontSize: 18,
                color: Colors.blueGrey,
                fontFamily: "ubuntu"
              ),
            ),
          ),
          Container(
            child: Text(
              _result[0]["text"],
              style: TextStyle(
                height: 1.8,
                fontSize: 16,
                color: Color.fromRGBO(20, 20, 40, 1)
              ),
            ),
          )
        ],
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          child: Row(
            children: <Widget>[
              Container(
                child: Icon(
                  FlutterIcons.pray_faw5s
                ),
              ),
              Container(
                margin: EdgeInsets.only(left: 18),
                child: Text(
                  "I Affirm"
                ),
              )
            ],
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
        child: FutureBuilder(
          future: getAffirmationDetails(),
          builder: (BuildContext _ctx, AsyncSnapshot _snapshot){
            if(_snapshot.hasData){
              return _snapshot.data;
            }
            else{
              return Center(
                child: CircularProgressIndicator(),
              );
            }
          },
        ),
      ),
    );
  }
}