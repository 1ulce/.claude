/* eslint-disable */
// Amazon Payのチェックアウトセッションで取得する住所と名前(姓名)を分割する
// https://github.com/amazonpay-labs/amazonpay-dividerの中身をコピー
// https://www.amazonpay-faq.jp/faq/QA-599
const amazonPayDivider = (function() {
  if (!Array.prototype.find) {
    Array.prototype.find = function(f) {
      return this.reduce(function(pre, cur) {
        if (pre !== null) return pre;
        return f(cur) ? cur : null;
      }, null);
    };
  }

  if (!String.prototype.startsWith) {
    Object.defineProperty(String.prototype, 'startsWith', {
      value: function(search, rawPos) {
        const pos = rawPos > 0 ? rawPos | 0 : 0;
        return this.substring(pos, pos + search.length) === search;
      },
    });
  }

  if (!(window.fetch || window.Request)) {
    window.Request = function(url, headers) {
      this.url = url;
      this.headers = headers || {};
    };

    window.fetch = (function() {
      return function(request) {
        const funcs = [];
        let result = null;
        let catchFunc = null;
        function thenLoop() {
          const f = funcs.shift();
          if (f) {
            try {
              result = f(result);
              setTimeout(thenLoop, 0);
            } catch (e) {
              if (catchFunc) catchFunc(e);
              else console.log(e);
            }
          }
        }
        setTimeout(function() {
          const xhr = new XMLHttpRequest();
          xhr.open('GET', request.url);
          xhr.send();
          xhr.onload = function() {
            result = {
              ok: true,
              text: function() {
                return xhr.response;
              },
            };
            setTimeout(thenLoop, 0);
          };
        }, 0);
        return {
          then: function(f) {
            funcs.push(f);
            return this;
          },
          catch: function(f) {
            catchFunc = f;
            return this;
          },
        };
      };
    })();
  }

  const kanjiToNum = (function() {
    const prime_table = {
      '０': 0,
      〇: 0,
      一: 1,
      二: 2,
      三: 3,
      四: 4,
      五: 5,
      六: 6,
      七: 7,
      八: 8,
      九: 9,
    };
    const sub_table = { 十: 10, 百: 100, 千: 1000 };
    const unit_table = { 万: 10000, 億: 100000000 };

    const primesReg = new RegExp(
      '[' + Object.keys(prime_table).join('') + ']',
      'g',
    );
    const unitsReg = new RegExp(
      '[' +
        Object.keys(sub_table)
          .concat(Object.keys(unit_table))
          .join('') +
        ']',
    );
    return function(kanji) {
      if (unitsReg.test(kanji)) {
        const obj = Array.prototype.reduce.call(
          kanji,
          function(o, cur) {
            let r;
            if ((r = prime_table[cur])) {
              o.prime = r;
            } else if ((r = sub_table[cur])) {
              o.subtotal += (o.prime || 1) * r;
              o.prime = 0;
            } else if ((r = unit_table[cur])) {
              o.total += (o.subtotal + o.prime) * r;
              o.subtotal = o.prime = 0;
            }
            return o;
          },
          { total: 0, subtotal: 0, prime: 0 },
        );
        return '' + (obj.total + obj.subtotal + obj.prime);
      } else {
        return kanji.replace(primesReg, function(s) {
          return prime_table[s];
        });
      }
    };
  })();

  function convertHalfWidthChar(str) {
    return str
      .replace(/[〇一二三四五六七八九十百千万]+/g, function(s) {
        return kanjiToNum(s);
      })
      .replace(/[０-９]/g, function(s) {
        return String.fromCharCode(s.charCodeAt(0) - 0xfee0);
      })
      .replace(
        /丁目[東西南北]?|丁|番耕?地|番|号|地割|-|‐|ー|−|－|―|ｰ|ノ|の/g,
        '-',
      )
      .replace(/-$/, '');
  }

  function convertProps(obj) {
    let success = true;
    for (const p in obj) {
      const v = obj[p];
      if (typeof v === 'string') obj[p] = v.trim();
      else if (Array.isArray(v))
        obj[p] = v
          .map(function(e) {
            return e.trim();
          })
          .join('');

      if (p === 'streetNumber') obj[p] = convertHalfWidthChar(obj[p]);

      if (p != 'building' && !obj[p])
        // buiding以外の値がない場合は分割失敗とみなす
        success = false;
    }
    obj.success = success;
    return obj;
  }

  function DivideAddressHelper(addressLine1, addressLine2, addressLine3) {
    this._addressLine1 = addressLine1;
    this._addressLine2 = addressLine2;
    this._addressLine3 = addressLine3;
  }

  DivideAddressHelper.prototype.divide = function(callback) {
    const that = this;
    const addressLine1 = _removeStateOrRegion(that._addressLine1); // 都道府県名を取り除く
    const addressLine2 = that._addressLine2 || '';
    const addressLine3 = that._addressLine3 || '';

    try {
      const streetNumber = _streetNumber();
      const result = streetNumber.divideIfSpecialCases(
        addressLine1,
        addressLine2,
        addressLine3,
      );
      if (result) {
        callback(convertProps(result));
        return;
      }

      const cityObj = _divideByCity(addressLine1);
      const townObj = _divideByTown(cityObj.townArea.concat(addressLine2)); // 丁目・番地・号で正規表現を適用する前に、「の」や「ノ」を含む町名を切り取る

      let streetNumberObj = streetNumber.divide(townObj.streetNumberArea);
      let building = [streetNumberObj.building, addressLine3];

      if (!streetNumberObj.streetNumber) {
        // 丁目・番地・号がない場合は、addressLine3にある可能性があるため、addressLine3を追加して再度分割
        streetNumberObj = streetNumber.divide(
          townObj.streetNumberArea + addressLine3,
        );
        building = [streetNumberObj.building];
      }

      callback(
        convertProps({
          city: cityObj.city,
          town: townObj.town || streetNumberObj.town,
          streetNumber: townObj.town
            ? [streetNumberObj.town, streetNumberObj.streetNumber]
            : streetNumberObj.streetNumber,
          building: building,
        }),
      );
    } catch (e) {
      callback(
        convertProps({
          city: addressLine1,
          town: '',
          streetNumber: addressLine2,
          building: addressLine3,
        }),
      );
    }

    function _removeStateOrRegion(addressLine1) {
      const stateOrRegionRegexp = /(北海道|青森県|岩手県|宮城県|秋田県|山形県|福島県|茨城県|栃木県|群馬県|埼玉県|千葉県|東京都|神奈川県|新潟県|富山県|石川県|福井県|山梨県|長野県|岐阜県|静岡県|愛知県|三重県|滋賀県|京都府|大阪府|兵庫県|奈良県|和歌山県|鳥取県|島根県|岡山県|広島県|山口県|徳島県|香川県|愛媛県|高知県|福岡県|佐賀県|長崎県|熊本県|大分県|宮崎県|鹿児島県|沖縄県)/;
      return addressLine1.replace(stateOrRegionRegexp, '');
    }

    function _divideByCity(addressLines) {
      const cityRegexp = /(田村|東村山|武蔵村山|羽村|十日町|野々市|大町|四日市|廿日市|大村|旭川|北見|富良野|伊達|石狩|南相馬|那須塩原|上越|富山|黒部|坂井|小諸|塩尻|豊川|松阪|福知山|姫路|玉野|下松|岩国|周南|田川|西海|別府|佐伯|蒲郡|鈴鹿|長浜|高槻|寝屋川|大和郡山|山口|丸亀|八代|都城|鹿児島)市|佐波郡玉村町|杵島郡大町町|九戸郡洋野町|.+?市.+?区|.+?郡.+?[町村]|.+?[市区町村]/;
      const divided = _divideBy(cityRegexp, addressLines);

      if (!divided.match)
        throw new Error(addressLines + ' does not include city.');

      return {
        city: divided.match,
        townArea: divided.right,
      };
    }

    function _divideByTown(addressLines) {
      const townRegexps = [
        /三ノ輪町三ノ輪/, // 豊橋市三ノ輪町三ノ輪
        /丁目(塩越|本通り|[東西南北横]町|[上下])/, // にかほ市象潟町５丁目塩越, 京都市伏見区京町８丁目横町, 十日町市本町一丁目上 など
        /[東西南北のノ][一二三四五六七八九十百千万]+丁目/, // 花巻市中北万丁目, 十日町市本町六ノ一丁目 など
        /[上下][一二三四五六七八九十]丁堀?/, // 横手市上八丁 など
        /[一二三四五六七八九十百千万０-９0-9]号[地東西南北]/, // 豊川市御津町佐脇浜三号地, 豊川市御津町御幸浜一号地,上川郡東川町東１０号南 など
        /[一二三四五六七八九十百千万０-９0-9][のノ之番丁東西南北][^一二三四五六七八九十百千万０-９0-9目耕地館 　]+/, // 二の宮, 五ノ神などの町域を抽出
        /字[^０-９0-9第]+/, // 岩手町大字五日市第１１地割５３番地３
        /[一二三四五六七八九十百千万０-９0-9]条[東西南北]?/,
      ];

      for (let i = 0; i < townRegexps.length; i++) {
        const townRegexp = townRegexps[i];
        const divided = _divideBy(townRegexp, addressLines);
        if (divided.match) {
          return {
            town: divided.left.concat(divided.match),
            streetNumberArea: divided.right,
          };
        }
      }

      return {
        town: '',
        streetNumberArea: addressLines,
      };
    }

    function _streetNumber() {
      const chrome =
        '[一二三四五六七八九十0-9０-９]{1,4}([-‐ー−－―ｰ一ノの]|丁目[東西南北]?)';
      const roomNumber = /[0-9０-９]+(号[棟室]|番館)/;

      const format1 =
        '第?(([一二三四五六七八九十百千万0-9０-９]+|[ABCＡＢＣ])(丁目[東西南北]?|丁|番耕?地|番|号|地割|-|‐|ー|−|－|―|ｰ|ノ|の)){1,3}[東西南北]?(([0-9０-９]+|[一二三四五六七八九十百千万]+)|(丁目|丁|番地|番|号地?|-|‐|ー|−|－|―|ｰ|ノ|の){1,2})*';
      const format2 =
        chrome +
        '([0-9０-９]{0,4}番地?[0-9０-９]{0,4}号?([-‐ー−－―ｰ一ノの][0-9０-９]{1,4}){0,2}|([0-9０-９]{1,4}[-‐ー−－―ｰ一ノの]){0,2}[0-9０-９]{1,4}号?)';
      const format3 = '[0-9０-９]+';

      /** addressLine1のsuffixが丁目の場合、divide */
      function _divideIfSpecialLine1(addressLine1, addressLine2, addressLine3) {
        const suffix = _endsWith(addressLine1);
        if (!suffix.match) return null;

        const cityObj = _divideByCity(suffix.left);
        return {
          city: cityObj.city,
          town: cityObj.townArea,
          streetNumber: suffix.match,
          building: [addressLine2, addressLine3],
        };
      }

      /** addressLine2のprefixが丁目の場合、divide */
      function _divideIfSpecialLine2(addressLine1, addressLine2, addressLine3) {
        const roomDivided = _divideByRoomNumber(addressLine2);
        const streetNumberSofar = roomDivided.match
          ? roomDivided.left
          : addressLine2;

        const prefix = _startsWith(streetNumberSofar);
        if (!prefix.match) return null;

        const cityObj = _divideByCity(addressLine1);
        const chromeObj = _divideByChrome(cityObj.townArea.trim()); // addressLine1に丁目までを記述する住所に対応
        return {
          city: cityObj.city,
          town: chromeObj.match ? chromeObj.left : cityObj.townArea, // addressLine1に丁目までを記述する場合、丁目を取り除きtownとする
          streetNumber: [chromeObj.match, prefix.match],
          building: [
            prefix.right,
            roomDivided.match,
            roomDivided.right,
            addressLine3,
          ],
        };
      }

      function _startsWith(addressLine) {
        return _divideBy('^' + format1, addressLine);
      }

      function _endsWith(addresLine) {
        const matchedFormat2 = _divideBy(format2 + '$', addresLine);
        if (matchedFormat2.match) return matchedFormat2;

        const matchedFormat3 = _divideBy(format3 + '$', addresLine);
        const NOT_FOUND = matchedFormat3.left.search(format3) === -1;
        if (matchedFormat3.match && NOT_FOUND) {
          // 目黒区下目黒10 アルコタワー100 のような住所の場合、100を丁目・番地と認識する恐れがあるため
          return matchedFormat3;
        }

        return {
          match: '',
        };
      }

      function _divideByChrome(addressLine) {
        return _divideBy(chrome, addressLine);
      }

      function _divideByRoomNumber(addressLine) {
        return _divideBy(roomNumber, addressLine);
      }

      return {
        divideIfSpecialCases: function(
          addressLine1,
          addressLine2,
          addressLine3,
        ) {
          return (
            _divideIfSpecialLine1(addressLine1, addressLine2, addressLine3) ||
            _divideIfSpecialLine2(addressLine1, addressLine2, addressLine3)
          );
        },
        divide: function(addressLines) {
          const streetNumberRegexps = [format1, format2, format3];
          const roomDivided = _divideByRoomNumber(addressLines);
          const streetNumerLines = roomDivided.match
            ? roomDivided.left
            : addressLines;

          for (let i = 0; i < streetNumberRegexps.length; i++) {
            const streetNumberRegexp = streetNumberRegexps[i];
            const divided = _divideBy(streetNumberRegexp, streetNumerLines);
            if (divided.match) {
              return {
                town: divided.left,
                streetNumber: divided.match,
                building: divided.right
                  .concat(roomDivided.match)
                  .concat(roomDivided.right),
              };
            }
          }

          if (roomDivided.match) {
            const index = addressLines.indexOf(roomDivided.match);
            return {
              town: addressLines.slice(0, index),
              streetNumber: '',
              building: roomDivided.match.concat(roomDivided.right),
            };
          }

          return {
            town: addressLines,
            streetNumber: '',
            building: '',
          };
        },
      };
    }

    function _divideBy(regexp, addressLines) {
      const matches = addressLines.match(regexp);

      if (!matches) {
        return _response();
      }

      const match = matches[0];
      const index = addressLines.indexOf(match);

      return _response(
        addressLines.slice(0, index),
        match,
        addressLines.slice(index + match.length),
      );

      function _response(left, match, right) {
        return {
          left: left || '',
          match: match || '',
          right: right || '',
        };
      }
    }
  };

  function DivideNameHelper(lastName, firstName) {
    this._lastName = lastName;
    this._firstName = firstName;
    this._initialUserName = lastName.slice(0, 1);
  }

  DivideNameHelper.prototype.divide = function(findAction) {
    const INITIAL_FILE =
        'https://d3e3b7ii96fk5l.cloudfront.net/amazonpay-divider/InitialIndex.csv',
      LASTNAMES_FILE =
        'https://d3e3b7ii96fk5l.cloudfront.net/amazonpay-divider/lastNames.csv',
      ROW_BYTES = 32; // LASTNAMES_FILE一行分のバイト数

    const that = this;
    try {
      _searchInitial(_findLastName);
    } catch (e) {
      console.error(e);
      _executeFindAction(that._lastName, '', that._firstName);
    }

    function _executeFindAction(lastName, lastNamePronunciation, firstName) {
      findAction({
        lastName: lastName,
        lastNamePronunciation: lastNamePronunciation,
        firstName: firstName,
      });
    }

    function _searchInitial(found) {
      _fetchInitials(function(text) {
        const initialBytes = text.split('\n').find(function(line) {
          return line.split(',')[0] == that._initialUserName;
        });

        if (!initialBytes) throw new Error('InitialLastName does not found.');

        const startBytes = Number(initialBytes.split(',')[1]);
        // 小が先頭につく名字が最も多く1076件存在するため、バッファ込みで1100件を取得
        const start = startBytes - ROW_BYTES * 3;
        found(start >= 0 ? start : 0, startBytes + ROW_BYTES * 1100);
      });
    }

    function _findLastName(start, end) {
      _fetchLastNames(start, end, function(text) {
        _getName(text);
      });
    }

    function _getName(text) {
      const longestLastName = _getLongestLastName(text, that._lastName);
      if (longestLastName.kanji) {
        // 姓名分割には成功したが、姓の読みを取得できなかった　例)lastName:森 firstName:久美子と分割できたが、longestNameが森久の場合
        if (that._firstName && longestLastName.kanji != that._lastName) {
          _executeFindAction(that._lastName, '', that._firstName);
          return;
        }

        that._firstName =
          that._firstName || that._lastName.replace(longestLastName.kanji, '');
        _executeFindAction(
          longestLastName.kanji,
          longestLastName.pronunciation,
          that._firstName,
        );
        return;
      }

      // 姓名分割には成功したが、姓の読みを取得できなかった
      if (that._firstName) {
        _executeFindAction(that._lastName, '', that._firstName);
        return;
      }

      throw new Error('lastName does not exist in the lastNames.');
    }

    function _fetchInitials(nextAction) {
      _fetch(INITIAL_FILE, nextAction);
    }

    function _fetchLastNames(start, end, nextAction) {
      _fetch(LASTNAMES_FILE, nextAction, {
        headers: {
          Range: 'bytes=' + start + '-' + end,
        },
      });
    }

    function _fetch(url, callback, headers) {
      const request = headers ? new Request(url, headers) : new Request(url);

      window
        .fetch(request)
        .then(function(res) {
          if (!res.ok) {
            console.error('response.status:', res.status);
            throw new Error(res.statusText);
          }
          return res.text();
        })
        .then(function(text) {
          callback(text);
        })
        .catch(function(e) {
          console.error(e);
          _executeFindAction(that._lastName, '', that._firstName);
        });
    }

    function _getLongestLastName(text, lastName) {
      const br = '\n';
      const start = text.indexOf(br) + 1;
      const count = text.lastIndexOf(br) - start;
      const lastNamesText = text.substr(start, count); // 改行で切れていない可能性があるため、CSVファイルの改行を探す

      if (!lastNamesText) {
        throw new Error('lastNamesText does not found.');
      }

      const lastNames = lastNamesText
        .split(br)
        .reduce(function(pre, cur, index) {
          const nameSet = cur.split(',');
          pre[index] = {
            kanji: nameSet[0],
            pronunciation: nameSet[1],
          };
          return pre;
        }, []);

      return lastNames.reduce(
        function(pre, cur) {
          return lastName.startsWith(cur.kanji) &&
            cur.kanji.length >= pre.kanji.length
            ? cur
            : pre;
        },
        {
          kanji: '',
          pronunciation: '',
        },
      );
    }
  };

  return {
    divideAddress: function(addressLines, callback) {
      new DivideAddressHelper(
        addressLines.addressLine1,
        addressLines.addressLine2,
        addressLines.addressLine3,
      ).divide(callback);
    },
    divideName: function(userName, callback) {
      // 全角半角スペースで分割する
      const name = userName
        .trim()
        .replace(/\u3000+/g, ' ')
        .replace(/\x20+/g, ' ')
        .split(' ');
      const lastName = name.shift();
      const firstName = name.join(' ');
      new DivideNameHelper(lastName, firstName).divide(callback);
    },
  };
})();

export default amazonPayDivider;
