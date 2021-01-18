// Copyright (c) 2020 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
import ballerina/test;
import ballerina/lang.'transaction as transactions;

@test:Config {
}
function testOnFailStatement() {
    string onFailResult = testReturnValInTrx();
    test:assertEquals(onFailResult, "start -> within transaction1 -> within transaction2 -> error handled");

    test:assertEquals(testLambdaFunctionWithOnFail(), 44);

    string nestedTrxWithLessOnFailsRestult = testNestedTrxWithLessOnFails();
    test:assertEquals(nestedTrxWithLessOnFailsRestult, "-> Before error 1 is thrown -> Before error 2 is thrown " +
    "-> Error caught !-> Execution continues...");

    string appendOnFailErrorResult = testAppendOnFailError();
    test:assertEquals("Before failure throw -> Error caught: custom error -> Execution continues...", appendOnFailErrorResult);
}

function testReturnValInTrx() returns string {
    string str = "start";
    transaction {
        str = str + " -> within transaction1";
        var ii = commit;
        error err = error("custom error", message = "error value");
        transaction {
            str = str + " -> within transaction2";
            var commitRes = commit;
        }
        int res2 = check getErrorForOnFail();
    } on fail error e {
        str += " -> error handled";
    }
    return str;
}

public function testLambdaFunctionWithOnFail() returns int {
    var lambdaFunc = function () returns int {
          int a = 10;
          int b = 11;
          int c = 0;
          transaction {
              error err = error("custom error", message = "error value");
              c = a + b;
              check commit;
              fail err;
          }
          on fail error e {
              function (int, int) returns int arrow = (x, y) => x + y + a + b + c;
              a = arrow(1, 1);
          }
          return a;
    };
    return lambdaFunc();
}

function testNestedTrxWithLessOnFails() returns string {
   string str = "";
   transaction {
      str += "-> Before error 1 is thrown";
      transaction {
          str += " -> Before error 2 is thrown";
          var resCommit2 = commit;
          int res2 =  check getErrorForOnFail();
      }
      var resCommit1 = commit;
   }
   on fail error e1 {
       str += " -> Error caught !";
   }
   str += "-> Execution continues...";
   return str;
}

function getErrorForOnFail() returns int|error {
  error err = error("custom error", message = "error value");
  return err;
}

function testAppendOnFailError() returns string {
   string str = "";
   transaction {
     error err = error("custom error", message = "error value");
     str += "Before failure throw";
     check commit;
     fail err;
   }
   on fail error e {
      str += " -> Error caught: ";
      str = str.concat(e.message());
   }
   str += " -> Execution continues...";
   return str;
}

@test:Config {
}
function testJumpingToOnFail() {
   string str = "";
   transaction {
      str += "-> Before error 1 is thrown";
      transaction {
          str += " -> Before error 2 is thrown";
          var resCommit2 = commit;
          int res2 =  check getErrorForOnFail();
      }
      str += "-> Should not reach here!";
      var resCommit1 = commit;
   }
   on fail error e1 {
       str += " -> Error caught! ";
   }
   str += "-> Execution continues...";

   test:assertEquals("-> Before error 1 is thrown -> Before error 2 is thrown -> Error caught!" +
   " -> Execution continues...", str);
}

@test:Config {
}
function testJumpingMultiLevelToOnFail() {
   string str = "";
   var onRollbackFunc1 = function(transactions:Info? info, error? cause, boolean willTry) {
           str += " -> trx 1 rollback";
   };
   var onRollbackFunc2 = function(transactions:Info? info, error? cause, boolean willTry) {
          str += " -> trx 2 rollback";
   };
   var onRollbackFunc3 = function(transactions:Info? info, error? cause, boolean willTry) {
         str += " -> trx 3 rollback";
   };
   transaction {
      str += "-> Before error 1 is thrown";
      transactions:onRollback(onRollbackFunc1);
      transaction {
          transactions:onRollback(onRollbackFunc2);
          transaction {
              transactions:onRollback(onRollbackFunc3);
              str += " -> Before error 2 is thrown";
              int res3 =  check getErrorForOnFail();
              var resCommit3 = commit;
          } on fail var e {
               str += " -> Error caught in inner onfail";
               fail e;
          }
          str += "-> Should not reach here!";
          var resCommit2 = commit;
      }
      str += "-> Should not reach here!";
      var resCommit1 = commit;
   }
   on fail error e1 {
       str += " -> Error caught in outter onfail";
   }
   str += " -> Execution continues...";

   test:assertEquals("-> Before error 1 is thrown -> Before error 2 is thrown -> trx 3 rollback -> Error caught in" +
   " inner onfail -> trx 2 rollback -> trx 1 rollback -> Error caught in outter onfail -> Execution continues...", str);
}
