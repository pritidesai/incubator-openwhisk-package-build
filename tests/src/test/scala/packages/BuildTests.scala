/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package packages

import org.junit.runner.RunWith
import org.scalatest.BeforeAndAfterAll
import org.scalatest.junit.JUnitRunner
import common._
import spray.json.DefaultJsonProtocol._
import spray.json._

@RunWith(classOf[JUnitRunner])
class BuildTests extends TestHelpers
    with WskTestHelpers
    with BeforeAndAfterAll {

    implicit val wskprops = WskProps()
    val wsk = new Wsk()

    "package get" should "contain build" in {
        withActivation(wsk.activation, wsk.pkg.get("/whisk.system/build")) {
            activation =>
            activation.response.success shouldBe true
        }
    }

    "action list" should "contain action nodejs" in {
        withActivation(wsk.activation, wsk.action.list()) {
            activation =>
            activation.response.success shouldBe true
        }
    }

    "nodejs action" should "create hello world action" in {
        val nodejsAction = "/whisk.system/build/nodejs"
        val actionData = "UEsDBBQAAAAIAFCNb0t5vViZmAAAANsAAAAIABwAaW5kZXguanNVVAkAAwjtDFrL8QxadXgLAAEE9QEAAAQUAAAARY9LDoMwDAX3OYW7CkiUAxR1331PYBVDIyUOdZJ+BNy9KZGod08ez5OHxLdoPMOdrPUvL7avJhR0oYZZQZ4nCgxeHEY4g9AjGaFKhyiGx2NZ6LrbUUZHGSyOdkvLAvoaBXkk0YWc8GM99hkshkpffv0NzOtBN5uk3kChmIRhBkch4Ein/XTt1KoUvScvMbQODWfb/4tOfQFQSwMEFAAAAAgAUI1vS+9BOJjjAAAAUQEAAAwAHABwYWNrYWdlLmpzb25VVAkAAwjtDFrL8QxadXgLAAEE9QEAAAQUAAAANY+xbsMwDERn+ysEzZXsFuiSrT/Qjp1liY2ZyKIg0m2DIP9eSXBX3vHd3X0cdHIb6JPSK8RI5odKDIbdliPopyoHYF8wC1JqrncKoD4ypM8V+aqcb4ISUrmQkNwyqFQtF1bLjjEotwttrn83WkQPiXveW3Z+BfNi564UyMQoVG5VvI/DoBusGc8ozTHovcReVCTzaZrqfd0X62mbckHB2tThhMnvi6scU/lXdwbTi9hGGYdHi/qGwsecZzsf+ZvDfsEU4Nde+BhflwZIHoH/a7EUTGfzRaXuah+zfa2Myh4f4x9QSwECHgMUAAAACABQjW9Leb1YmZgAAADbAAAACAAYAAAAAAABAAAApIEAAAAAaW5kZXguanNVVAUAAwjtDFp1eAsAAQT1AQAABBQAAABQSwECHgMUAAAACABQjW9L70E4mOMAAABRAQAADAAYAAAAAAABAAAApIHaAAAAcGFja2FnZS5qc29uVVQFAAMI7QxadXgLAAEE9QEAAAQUAAAAUEsFBgAAAAACAAIAoAAAAAMCAAAAAA=="
        val params = Map("action_name" -> "build-helloworld-nodejs".toJson,"action_data" -> actionData.toJson);

        withActivation(wsk.activation, wsk.action.invoke(nodejsAction, params)) {
            activation =>
            activation.response.success shouldBe true
        }
        // cleanup after test
        wsk.action.delete("build-helloworld-nodejs")
    }
}


