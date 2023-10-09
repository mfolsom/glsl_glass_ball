float sphereSDF(vec3 p,vec3 center,float radius){
    return length(p-center)-radius;
}

float march(vec3 ro,vec3 rd){
    float totalDistance=0.;
    for(int i=0;i<64;i++){
        vec3 p=ro+totalDistance*rd;
        float d=sphereSDF(p,vec3(0.),1.);// Sphere centered at origin with radius 1
        if(d<.001)return totalDistance;// we're close enough to the surface
        totalDistance+=d;
    }
    return-1.;// didn't hit anything
}

vec3 getNormal(vec3 p){
    const vec2 eps=vec2(.001,0.);
    return normalize(vec3(
            sphereSDF(p+eps.xyy,vec3(0.),1.)-sphereSDF(p-eps.xyy,vec3(0.),1.),
            sphereSDF(p+eps.yxy,vec3(0.),1.)-sphereSDF(p-eps.yxy,vec3(0.),1.),
            sphereSDF(p+eps.yyx,vec3(0.),1.)-sphereSDF(p-eps.yyx,vec3(0.),1.)
        ));
    }
    
    float fresnel(vec3 incoming,vec3 normal,float ior){
        float cosi=clamp(-1.,1.,dot(incoming,normal));
        float etai=1.,etat=ior;
        if(cosi>0.){
            float temp=etai;
            etai=etat;
            etat=temp;
        }
        float sint=etai/etat*sqrt(max(0.,1.-cosi*cosi));
        if(sint>=1.){
            return 1.;
        }else{
            float cost=sqrt(max(0.,1.-sint*sint));
            cosi=abs(cosi);
            float Rs=((etat*cosi)-(etai*cost))/((etat*cosi)+(etai*cost));
            float Rp=((etai*cosi)-(etat*cost))/((etai*cosi)+(etat*cost));
            return(Rs*Rs+Rp*Rp)/2.;
        }
    }
    
    vec3 reflectVec(vec3 incoming,vec3 normal){
        return incoming-2.*dot(incoming,normal)*normal;
    }
    
    vec3 refractVec(vec3 incoming,vec3 normal,float ior){
        float cosi=clamp(-1.,1.,dot(incoming,normal));
        float etai=1.,etat=ior;
        vec3 n=normal;
        if(cosi<0.){
            cosi=-cosi;
        }else{
            float temp=etai;
            etai=etat;
            etat=temp;
            n=-normal;
        }
        float eta=etai/etat;
        float k=1.-eta*eta*(1.-cosi*cosi);
        return k<0.?vec3(0.):eta*incoming+(eta*cosi-sqrt(k))*n;
    }
    
    const vec3 ambientColor=vec3(.2,.24,.6);// Low intensity light
    
    const float PI=3.14159265359;
    
    mat3 rotateX(float angle){
        float s=sin(angle);
        float c=cos(angle);
        return mat3(
            1.,0.,0.,
            0.,c,-s,
            0.,s,c
        );
    }
    
    mat3 rotateY(float angle){
        float s=sin(angle);
        float c=cos(angle);
        return mat3(
            c,0.,s,
            0.,1.,0.,
            -s,0.,c
        );
    }
    
    vec3 sampleCubemap(vec3 direction){
        return texture(iChannel0,direction).rgb;
    }
    
    vec3 sceneColor(vec3 rayDir){
        float gradient=.5*(rayDir.y+1.);// Convert y from [-1, 1] to [0, 1]
        vec3 topColor=vec3(.5,.7,1.);// Sky color
        vec3 bottomColor=vec3(1.,.9,.8);// Ground color
        return mix(bottomColor,topColor,gradient);
    }
    
    void mainImage(out vec4 fragColor,in vec2 fragCoord)
    {
        vec2 uv=fragCoord/iResolution.xy;
        uv=uv*2.-1.;
        uv.x*=iResolution.x/iResolution.y;
        
        vec3 center=vec3(0.,0.,0.);
        vec3 ro=vec3(0.,0.,-2.);
        vec3 rd=normalize(vec3(uv,1.));
        
        float rotationAngle=iTime;
        
        float d=march(ro,rd);
        vec3 col=vec3(0.);
        
        if(d!=-1.){
            vec3 p=ro+d*rd;
            
            // Rotate intersection point to give appearance of spinning sphere
            p-=center;
            p=rotateY(rotationAngle)*p;
            p+=center;
            
            vec3 originalNormal=getNormal(p);// Fixed the case of the variable name here
            vec3 normal=rotateY(rotationAngle)*originalNormal;// Fixed the case of the variable name here
            float fresnelEffect=fresnel(-rd,originalNormal,1.25);
            
            vec3 reflected=reflectVec(-rd,normal);
            reflected.y=-reflected.y;
            vec3 refracted=refractVec(-rd,normal,1.25);
            refracted.y=-refracted.y;
            
            vec3 reflectionColor=sampleCubemap(reflected);
            vec3 refractionColor=sampleCubemap(refracted);
            
            col=mix(refractionColor,reflectionColor,fresnelEffect);
        }else{
            col=sampleCubemap(rd);
        }
        
        fragColor=vec4(col,1.);
    }
    