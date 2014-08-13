package openfl._internal.renderer.opengl.utils ;


import lime.graphics.GLRenderContext;
import lime.utils.Float32Array;
import openfl._internal.renderer.opengl.shaders.AbstractShader;
import openfl._internal.renderer.opengl.utils.GraphicsRenderer;
import openfl._internal.renderer.RenderSession;


class StencilManager {
	
	
	public var count:Int;
	public var gl:GLRenderContext;
	public var maskStack:Array<Dynamic>;
	public var reverse:Bool;
	public var stencilStack:Array<Dynamic>;
	
	private var _currentGraphics:Dynamic;
	
	
	public function new (gl:GLRenderContext) {
		
		stencilStack = [];
		setContext (gl);
		reverse = true;
		count = 0;
		
	}
	
	
	public function bindGraphics (graphics:Dynamic, webGLData:GLGraphicsData, renderSession:RenderSession):Void {
		
		_currentGraphics = graphics;
		
		var gl = this.gl;
		
		var projection = renderSession.projection;
		var offset = renderSession.offset;
		
		if (webGLData.mode == 1) {
			
			var shader = renderSession.shaderManager.complexPrimitiveShader;
			renderSession.shaderManager.setShader (shader);
			
			gl.uniformMatrix3fv (shader.translationMatrix, false, graphics.worldTransform.toArray (true));
			
			gl.uniform2f (shader.projectionVector, projection.x, -projection.y);
			gl.uniform2f (shader.offsetVector, -offset.x, -offset.y);
			
			gl.uniform3fv (shader.tintColor, new Float32Array (GraphicsRenderer.hex2rgb (graphics.tint)));
			gl.uniform3fv (shader.color, new Float32Array (webGLData.color));
			
			gl.uniform1f (shader.alpha, graphics.worldAlpha * webGLData.alpha);
			
			gl.bindBuffer (gl.ARRAY_BUFFER, webGLData.buffer);
			
			gl.vertexAttribPointer (shader.aVertexPosition, 2, gl.FLOAT, false, 4 * 2, 0);
			
			gl.bindBuffer (gl.ELEMENT_ARRAY_BUFFER, webGLData.indexBuffer);
			
		} else {
			
			var shader = renderSession.shaderManager.primitiveShader;
			renderSession.shaderManager.setShader (shader);
			
			gl.uniformMatrix3fv (shader.translationMatrix, false, graphics.worldTransform.toArray (true));
			
			gl.uniform2f (shader.projectionVector, projection.x, -projection.y);
			gl.uniform2f (shader.offsetVector, -offset.x, -offset.y);
			
			gl.uniform3fv (shader.tintColor, new Float32Array (GraphicsRenderer.hex2rgb (graphics.tint)));
			
			gl.uniform1f (shader.alpha, graphics.worldAlpha);
			
			gl.bindBuffer (gl.ARRAY_BUFFER, webGLData.buffer);
			
			gl.vertexAttribPointer (shader.aVertexPosition, 2, gl.FLOAT, false, 4 * 6, 0);
			gl.vertexAttribPointer (shader.colorAttribute, 4, gl.FLOAT, false,4 * 6, 2 * 4);
			
			gl.bindBuffer (gl.ELEMENT_ARRAY_BUFFER, webGLData.indexBuffer);
			
		}
		
	}
	
	
	public function destroy ():Void {
		
		maskStack = null;
		gl = null;
		
	}
	
	
	public function popStencil (graphics:Dynamic, webGLData:GLGraphicsData, renderSession:RenderSession):Void {
		
		var gl = this.gl;
		this.stencilStack.pop ();
		
		count--;
		
		if (stencilStack.length == 0) {
				
			gl.disable (gl.STENCIL_TEST);
			
		} else {
			
			var level = count;
			bindGraphics (graphics, webGLData, renderSession);
			
			gl.colorMask (false, false, false, false);
			
			if (webGLData.mode == 1) {
				
				reverse = !reverse;
				
				if (reverse) {
					
					gl.stencilFunc (gl.EQUAL, 0xFF - (level + 1), 0xFF);
					gl.stencilOp (gl.KEEP, gl.KEEP, gl.INCR);
					
				} else {
					
					gl.stencilFunc (gl.EQUAL, level + 1, 0xFF);
					gl.stencilOp (gl.KEEP, gl.KEEP, gl.DECR);
					
				}
				
				gl.drawElements (gl.TRIANGLE_FAN, 4, gl.UNSIGNED_SHORT, (webGLData.indices.length - 4) * 2);
				
				gl.stencilFunc (gl.ALWAYS, 0, 0xFF);
				gl.stencilOp (gl.KEEP, gl.KEEP, gl.INVERT);
				
				gl.drawElements (gl.TRIANGLE_FAN, Std.int (webGLData.indices.length - 4), gl.UNSIGNED_SHORT, 0);
				
				if (!reverse) {
					
					gl.stencilFunc (gl.EQUAL, 0xFF - (level), 0xFF);
					
				} else {
					
					gl.stencilFunc (gl.EQUAL, level, 0xFF);
					
				}
				
			} else {
				
				if (!reverse) {
					
					gl.stencilFunc (gl.EQUAL, 0xFF - (level + 1), 0xFF);
					gl.stencilOp (gl.KEEP, gl.KEEP, gl.INCR);
					
				} else {
					
					gl.stencilFunc (gl.EQUAL, level + 1, 0xFF);
					gl.stencilOp (gl.KEEP, gl.KEEP, gl.DECR);
					
				}
				
				gl.drawElements (gl.TRIANGLE_STRIP, webGLData.indices.length, gl.UNSIGNED_SHORT, 0);
				
				if (!reverse) {
					
					gl.stencilFunc (gl.EQUAL, 0xFF - (level), 0xFF);
					
				} else {
					
					gl.stencilFunc (gl.EQUAL, level, 0xFF);
					
				}
				
			}
			
			gl.colorMask (true, true, true, true);
			gl.stencilOp (gl.KEEP, gl.KEEP, gl.KEEP);
			
		}
		
	}
	
	
	public function pushStencil (graphics:Dynamic, webGLData:GLGraphicsData, renderSession:RenderSession):Void {
		
		var gl = this.gl;
		bindGraphics (graphics, webGLData, renderSession);
		
		if (stencilStack.length == 0) {
			
			gl.enable (gl.STENCIL_TEST);
			gl.clear (gl.STENCIL_BUFFER_BIT);
			reverse = true;
			count = 0;
			
		}
		
		stencilStack.push (webGLData);
		
		var level = count;
		
		gl.colorMask (false, false, false, false);
		
		gl.stencilFunc (gl.ALWAYS, 0, 0xFF);
		gl.stencilOp (gl.KEEP, gl.KEEP, gl.INVERT);
		
		if (webGLData.mode == 1) {
			
			gl.drawElements (gl.TRIANGLE_FAN, webGLData.indices.length - 4, gl.UNSIGNED_SHORT, 0);
			
			if (reverse) {
				
				gl.stencilFunc (gl.EQUAL, 0xFF - level, 0xFF);
				gl.stencilOp (gl.KEEP, gl.KEEP, gl.DECR);
				
			} else {
				
				gl.stencilFunc (gl.EQUAL, level, 0xFF);
				gl.stencilOp (gl.KEEP, gl.KEEP, gl.INCR);
				
			}
			
			gl.drawElements (gl.TRIANGLE_FAN, 4, gl.UNSIGNED_SHORT, Std.int ((webGLData.indices.length - 4) * 2));
			
			if (reverse) {
				
				gl.stencilFunc (gl.EQUAL, 0xFF - (level + 1), 0xFF);
				
			} else {
				
				gl.stencilFunc (gl.EQUAL, level + 1, 0xFF);
				
			}
			
			reverse = !reverse;
			
		} else {
				
			if (!reverse) {
				
				gl.stencilFunc (gl.EQUAL, 0xFF - level, 0xFF);
				gl.stencilOp (gl.KEEP, gl.KEEP, gl.DECR);
				
			} else {
				
				gl.stencilFunc (gl.EQUAL, level, 0xFF);
				gl.stencilOp (gl.KEEP, gl.KEEP, gl.INCR);
				
			}
			
			gl.drawElements (gl.TRIANGLE_STRIP, webGLData.indices.length, gl.UNSIGNED_SHORT, 0);
			
			if (!reverse) {
				
				gl.stencilFunc (gl.EQUAL, 0xFF - (level + 1), 0xFF);
				
			} else {
				
				gl.stencilFunc (gl.EQUAL, level + 1, 0xFF);
				
			}
			
		}
		
		gl.colorMask (true, true, true, true);
		gl.stencilOp (gl.KEEP, gl.KEEP, gl.KEEP);
		
		this.count++;
		
	}
	
	
	public function setContext (gl:GLRenderContext):Void {
		
		this.gl = gl;
		
	}
	
	
}