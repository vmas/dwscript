object dwsEncodingLib: TdwsEncodingLib
  OldCreateOrder = False
  Left = 695
  Top = 86
  Height = 150
  Width = 215
  object dwsEncoding: TdwsUnit
    Classes = <
      item
        Name = 'Encoder'
        IsAbstract = True
        Methods = <
          item
            Name = 'Encode'
            Parameters = <
              item
                Name = 'v'
                DataType = 'String'
              end>
            ResultType = 'String'
            Attributes = [maVirtual, maAbstract]
            Kind = mkClassFunction
          end
          item
            Name = 'Decode'
            Parameters = <
              item
                Name = 'v'
                DataType = 'String'
              end>
            ResultType = 'String'
            Attributes = [maVirtual, maAbstract]
            Kind = mkClassFunction
          end>
      end
      item
        Name = 'UTF8Encoder'
        Ancestor = 'Encoder'
        Methods = <
          item
            Name = 'Encode'
            Parameters = <
              item
                Name = 'v'
                DataType = 'String'
              end>
            ResultType = 'String'
            Attributes = [maVirtual, maOverride]
            OnEval = dwsEncodingClassesUTF8EncoderMethodsEncodeEval
            Kind = mkClassFunction
          end
          item
            Name = 'Decode'
            Parameters = <
              item
                Name = 'v'
                DataType = 'String'
              end>
            ResultType = 'String'
            Attributes = [maVirtual, maOverride]
            OnEval = dwsEncodingClassesUTF8EncoderMethodsDecodeEval
            Kind = mkClassFunction
          end>
      end
      item
        Name = 'URLEncodedEncoder'
        Ancestor = 'Encoder'
        Methods = <
          item
            Name = 'Encode'
            Parameters = <
              item
                Name = 'v'
                DataType = 'String'
              end>
            ResultType = 'String'
            Attributes = [maVirtual, maOverride]
            OnEval = dwsEncodingClassesURLEncodedEncoderMethodsEncodeEval
            Kind = mkClassFunction
          end
          item
            Name = 'Decode'
            Parameters = <
              item
                Name = 'v'
                DataType = 'String'
              end>
            ResultType = 'String'
            Attributes = [maVirtual, maOverride]
            OnEval = dwsEncodingClassesURLEncodedEncoderMethodsDecodeEval
            Kind = mkClassFunction
          end>
      end>
    UnitName = 'System.Encoding'
    StaticSymbols = False
    Left = 72
    Top = 32
  end
end
