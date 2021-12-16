import openfl.display.Sprite;
import haxe.ui.core.Component;

/**
    https://github.com/haxeui/haxeui-openfl/issues/23
**/
class SpriteContainer extends Component {
    public function new() {
        super();
    }
    
    private var _sprite:Sprite;
    public var sprite(get, set):Sprite;
    private function get_sprite():Sprite {
        return _sprite;
    }
    private function set_sprite(value):Sprite {
        _sprite = value;
        addChild(_sprite);
        return value;
    }
    
    private override function validateComponentLayout():Bool {
        return super.validateComponentLayout();
        if (_sprite != null) {
            _sprite.width = width;
            _sprite.height = height;
        }
        return super.validateComponentLayout();
    }
}