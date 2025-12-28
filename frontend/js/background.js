// 3D Animated Background with Three.js
(function() {
    const canvas = document.getElementById('bg-canvas');
    if (!canvas || !window.THREE) return;

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
    const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });

    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

    // Camera position
    camera.position.z = 30;

    // Create particles
    const particlesGeometry = new THREE.BufferGeometry();
    const particlesCount = 2000;
    const posArray = new Float32Array(particlesCount * 3);

    for(let i = 0; i < particlesCount * 3; i++) {
        posArray[i] = (Math.random() - 0.5) * 100;
    }

    particlesGeometry.setAttribute('position', new THREE.BufferAttribute(posArray, 3));

    const particlesMaterial = new THREE.PointsMaterial({
        size: 0.15,
        color: 0x00f5ff,
        transparent: true,
        opacity: 0.8,
        blending: THREE.AdditiveBlending
    });

    const particlesMesh = new THREE.Points(particlesGeometry, particlesMaterial);
    scene.add(particlesMesh);

    // Create grid
    const gridHelper = new THREE.GridHelper(100, 50, 0x00f5ff, 0x7c3aed);
    gridHelper.rotation.x = Math.PI / 2;
    gridHelper.position.z = -20;
    gridHelper.material.opacity = 0.2;
    gridHelper.material.transparent = true;
    scene.add(gridHelper);

    // Create wireframe spheres
    const geometry = new THREE.IcosahedronGeometry(8, 1);
    const material = new THREE.MeshBasicMaterial({
        color: 0x00f5ff,
        wireframe: true,
        transparent: true,
        opacity: 0.3
    });
    const sphere1 = new THREE.Mesh(geometry, material);
    sphere1.position.set(-15, 0, -10);
    scene.add(sphere1);

    const sphere2 = new THREE.Mesh(geometry.clone(), material.clone());
    sphere2.material.color = new THREE.Color(0xff00e5);
    sphere2.position.set(15, 0, -10);
    sphere2.scale.set(0.7, 0.7, 0.7);
    scene.add(sphere2);

    // Mouse movement
    let mouseX = 0;
    let mouseY = 0;

    document.addEventListener('mousemove', (event) => {
        mouseX = (event.clientX / window.innerWidth) * 2 - 1;
        mouseY = -(event.clientY / window.innerHeight) * 2 + 1;
    });

    // Animation
    let time = 0;
    function animate() {
        requestAnimationFrame(animate);
        time += 0.001;

        // Rotate particles
        particlesMesh.rotation.y += 0.0005;
        particlesMesh.rotation.x += 0.0003;

        // Wave effect on particles
        const positions = particlesMesh.geometry.attributes.position.array;
        for(let i = 0; i < positions.length; i += 3) {
            positions[i + 1] = Math.sin(time + positions[i] * 0.1) * 2;
        }
        particlesMesh.geometry.attributes.position.needsUpdate = true;

        // Rotate spheres
        sphere1.rotation.y += 0.003;
        sphere1.rotation.x += 0.002;
        sphere2.rotation.y -= 0.004;
        sphere2.rotation.x -= 0.003;

        // Grid animation
        gridHelper.position.z = -20 + Math.sin(time * 2) * 2;

        // Camera movement based on mouse
        camera.position.x += (mouseX * 5 - camera.position.x) * 0.05;
        camera.position.y += (mouseY * 5 - camera.position.y) * 0.05;
        camera.lookAt(scene.position);

        renderer.render(scene, camera);
    }

    animate();

    // Handle window resize
    window.addEventListener('resize', () => {
        camera.aspect = window.innerWidth / window.innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(window.innerWidth, window.innerHeight);
    });
})();
