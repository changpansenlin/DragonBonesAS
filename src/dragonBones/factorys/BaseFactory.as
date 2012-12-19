package dragonBones.factorys
{
	import dragonBones.Armature;
	import dragonBones.Bone;
	import dragonBones.display.NativeDisplayBridge;
	import dragonBones.objects.AnimationData;
	import dragonBones.objects.ArmatureData;
	import dragonBones.objects.BoneData;
	import dragonBones.objects.DecompressedData;
	import dragonBones.objects.DisplayData;
	import dragonBones.objects.SkeletonData;
	import dragonBones.objects.XMLDataParser;
	import dragonBones.textures.ITextureAtlas;
	import dragonBones.textures.NativeTextureAtlas;
	import dragonBones.textures.SubTextureData;
	import dragonBones.utils.BytesType;
	import dragonBones.utils.dragonBones_internal;
	
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.geom.Matrix;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
	
	use namespace dragonBones_internal;
	
	/** Dispatched when the textureData init completed. */
	[Event(name="complete", type="flash.events.Event")]
	
	/**
	 * A object managing the set of armature resources for the tranditional DisplayList. It parses the raw data, stores the armature resources and creates armature instrances.
	 * @see dragonBones.Armature
	 */
	public class BaseFactory extends EventDispatcher
	{
		private static var _helpMatirx:Matrix = new Matrix();
		private static var _loaderContext:LoaderContext = new LoaderContext(false);
		
		protected var _skeletonDataDic:Object;
		protected var _textureAtlasDic:Object;
		protected var _textureAtlasLoadingDic:Object;
		
		protected var _currentSkeletonData:SkeletonData;
		protected var _currentTextureAtlas:ITextureAtlas;
		protected var _currentSkeletonName:String;
		protected var _currentTextureAtlasName:String;
		
		/**
		 * Creates a new <code>BaseFactory</code>
		 *
		 */
		public function BaseFactory()
		{
			super();
			_skeletonDataDic = {};
			_textureAtlasDic = {};
			_textureAtlasLoadingDic = {};
			
			_loaderContext.allowCodeImport = true;
		}
		
		/**
		 * Pareses the raw data.
		 * @param	bytes Represents the raw data for the whole skeleton system.
		 */
		public function parseData(bytes:ByteArray, skeletonName:String = null):SkeletonData
		{
			var decompressedData:DecompressedData = XMLDataParser.decompressData(bytes);
			
			var skeletonData:SkeletonData = XMLDataParser.parseSkeletonData(decompressedData.skeletonXML);
			skeletonName = skeletonName || skeletonData.name;
			addSkeletonData(skeletonData, skeletonName);
			
			var loader:Loader = new Loader();
			loader.name = skeletonName;
			_textureAtlasLoadingDic[skeletonName] = decompressedData.textureAtlasXML;
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loaderCompleteHandler);
			loader.loadBytes(decompressedData.textureBytes, _loaderContext);
			
			decompressedData.dispose();
			return skeletonData;
		}
		
		public function getSkeletonData(name:String):SkeletonData
		{
			return _skeletonDataDic[name];
		}
		
		public function addSkeletonData(skeletonData:SkeletonData, name:String = null):void
		{
			name = name || skeletonData.name;
			if(name)
			{
				_skeletonDataDic[name] = skeletonData;
			}
		}
		
		public function removeSkeletonData(name:String):void
		{
			delete _skeletonDataDic[name];
		}
		
		public function getTextureAtlas(name:String):ITextureAtlas
		{
			return _textureAtlasDic[name];
		}
		
		public function addTextureAtlas(textureAtlas:ITextureAtlas, name:String = null):void
		{
			name = name || textureAtlas.name;
			if(name)
			{
				_textureAtlasDic[name] = textureAtlas;
			}
		}
		
		public function removeTextureAtlas(name:String):void
		{
			delete _textureAtlasDic[name];
		}
		
		/**
		 * Cleans up any resources used by the current object.
		 */
		public function dispose():void
		{
			for each(var skeletonData:SkeletonData in _skeletonDataDic)
			{
				skeletonData.dispose();
			}
			_skeletonDataDic = null;
			
			for each(var textureAtlas:ITextureAtlas in _textureAtlasDic)
			{
				textureAtlas.dispose();
			}
			_textureAtlasDic = null;
			
			_textureAtlasLoadingDic = null;
			
			_currentSkeletonData = null;
		}
		
		/**
		 * Builds a new armature by name
		 * @param	armatureName
		 * @return
		 */
		public function buildArmature(armatureName:String, animationName:String = null, skeletonName:String = null, textureAtlasName:String = null):Armature
		{
			var skeletonData:SkeletonData;
			var armatureData:ArmatureData;
			if(skeletonName)
			{
				skeletonData = _skeletonDataDic[skeletonName];
				if(skeletonData)
				{
					armatureData = skeletonData.getArmatureData(armatureName);
				}
			}
			else
			{
				for (skeletonName in _skeletonDataDic)
				{
					skeletonData = _skeletonDataDic[skeletonName];
					armatureData = skeletonData.getArmatureData(armatureName);
					if(armatureData)
					{
						break;
					}
				}
			}
			if(!armatureData)
			{
				return null;
			}
			_currentSkeletonName = skeletonName;
			_currentSkeletonData = skeletonData;

			_currentTextureAtlasName = textureAtlasName || skeletonName;
			_currentTextureAtlas = _textureAtlasDic[_currentTextureAtlasName];
			
			var animationData:AnimationData = _currentSkeletonData.getAnimationData(animationName || armatureName);
			var armature:Armature = generateArmature();
			armature.name = armatureName;
			armature.animation.setData(animationData);
			var boneList:Vector.<String> = armatureData.boneList;
			for each(var boneName:String in boneList)
			{
				var boneData:BoneData = armatureData.getBoneData(boneName);
				if(boneData)
				{
					var bone:Bone = buildBone(boneData);
					armature.addBone(bone, boneData.parent);
				}
			}
			armature.update();
			return armature;
		}
		
		public function getTextureDisplay(textureName:String, textureAtlasName:String = null, pivotX:Number = NaN, pivotY:Number = NaN):Object
		{
			var textureAtlas:ITextureAtlas;
			if(textureAtlasName)
			{
				textureAtlas = _textureAtlasDic[textureAtlasName];
			}
			else
			{
				for (textureAtlasName in _textureAtlasDic)
				{
					textureAtlas = _textureAtlasDic[textureAtlasName];
					if(textureAtlas.getRegion(textureName))
					{
						break;
					}
					textureAtlas = null;
				}
			}
			if(textureAtlas)
			{
				if(isNaN(pivotX) || isNaN(pivotY))
				{
					var skeletonData:SkeletonData = _skeletonDataDic[textureAtlasName];
					if(skeletonData)
					{
						var displayData:DisplayData = skeletonData.getDisplayData(textureName);
						if(displayData)
						{
							pivotX = pivotX || displayData.pivotX;
							pivotY = pivotY || displayData.pivotY;
						}
					}
				}
				
				return generateTextureDisplay(textureAtlas, textureName, pivotX, pivotY);
			}
			return null;
		}
		
		protected function buildBone(boneData:BoneData):Bone
		{
			var bone:Bone = generateBone();
			bone.origin.copy(boneData);
			bone.name = boneData.name;
			
			var displayData:DisplayData;
			for(var i:int = boneData.totalDisplays - 1;i >= 0;i --)
			{
				var displayName:String = boneData.getDisplayDataAt(i);
				displayData = _currentSkeletonData.getDisplayData(displayName);
				bone.changeDisplay(i);
				if (displayData.isArmature)
				{
					var childArmature:Armature = buildArmature(displayName, null, _currentSkeletonName, _currentTextureAtlasName);
					if(childArmature)
					{
						childArmature.animation.play();
						bone.display = childArmature;
					}
				}
				else
				{
					bone.display = generateTextureDisplay(_currentTextureAtlas, displayName, displayData.pivotX, displayData.pivotY);
				}
			}
			return bone;
		}
		
		protected function loaderCompleteHandler(e:Event):void
		{
			e.target.removeEventListener(Event.COMPLETE, loaderCompleteHandler);
			var loader:Loader = e.target.loader;
			var content:Object = e.target.content;
			loader.unloadAndStop();
			
			var skeletonName:String = loader.name;
			var textureAtlasXML:XML = _textureAtlasLoadingDic[skeletonName];
			delete _textureAtlasLoadingDic[skeletonName];
			if(skeletonName && textureAtlasXML)
			{
				if (content is Bitmap)
				{
					content =  (content as Bitmap).bitmapData;
				}
				else if (content is Sprite)
				{
					content = (content as Sprite).getChildAt(0) as MovieClip;
				}
				
				var textureAtlas:ITextureAtlas = generateTextureAtlas(content, textureAtlasXML);
				addTextureAtlas(textureAtlas, skeletonName);
				
				skeletonName = null;
				for(skeletonName in _textureAtlasLoadingDic)
				{
					break;
				}
				//
				if(!skeletonName && hasEventListener(Event.COMPLETE))
				{
					dispatchEvent(new Event(Event.COMPLETE));
				}
			}
		}
		
		protected function generateTextureAtlas(content:Object, textureAtlasXML:XML):ITextureAtlas
		{
			var textureAtlas:NativeTextureAtlas = new NativeTextureAtlas(content, textureAtlasXML);
			return textureAtlas;
		}
		
		protected function generateArmature():Armature
		{
			var display:Sprite = new Sprite();
			var armature:Armature = new Armature(display);
			return armature;
		}
		
		protected function generateBone():Bone
		{
			var bone:Bone = new Bone(new NativeDisplayBridge());
			return bone;
		}
		
		protected function generateTextureDisplay(textureAtlas:ITextureAtlas, fullName:String, pivotX:int, pivotY:int):Object
		{
			var nativeTextureAtlas:NativeTextureAtlas = textureAtlas as NativeTextureAtlas;
			if(nativeTextureAtlas){
				if (nativeTextureAtlas.movieClip)
				{
					var movieClip:MovieClip = nativeTextureAtlas.movieClip;
					movieClip.gotoAndStop(movieClip.totalFrames);
					movieClip.gotoAndStop(fullName);
					if (movieClip.numChildren > 0)
					{
						try
						{
							var displaySWF:Object = movieClip.getChildAt(0);
							displaySWF.x = 0;
							displaySWF.y = 0;
							return displaySWF;
						}
						catch(e:Error)
						{
							throw "Can not get the movie clip, please make sure the version of the resource compatible with app version!";
						}
					}
				}
				else if(nativeTextureAtlas.bitmapData)
				{
					var subTextureData:SubTextureData = nativeTextureAtlas.getRegion(fullName) as SubTextureData;
					if (subTextureData)
					{
						var displayShape:Shape = new Shape();
						//1.4
						pivotX = pivotX || subTextureData.pivotX;
						pivotY = pivotY || subTextureData.pivotY;
						_helpMatirx.a = 1;
						_helpMatirx.b = 0;
						_helpMatirx.c = 0;
						_helpMatirx.d = 1;
						_helpMatirx.scale(nativeTextureAtlas.scale, nativeTextureAtlas.scale);
						_helpMatirx.tx = -subTextureData.x - pivotX;
						_helpMatirx.ty = -subTextureData.y - pivotY;
						
						displayShape.graphics.beginBitmapFill(nativeTextureAtlas.bitmapData, _helpMatirx, false);
						displayShape.graphics.drawRect(-pivotX, -pivotY, subTextureData.width, subTextureData.height);
						return displayShape;
					}
				}
			}
			return null;
		}
	}
}