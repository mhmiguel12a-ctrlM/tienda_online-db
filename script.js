import { createClient } from '@supabase/supabase-js'
const supabaseUrl = 'https://kpfnejfkdgbtrpvxanka.supabase.co'
const supabaseKey = process.env.SUPABASE_KEY
const supabase = createClient(supabaseUrl, supabaseKey)
async function cargarProductos() {

const client = supabase.createClient(
    supabaseUrl,
    supabaseKey
);

    const { data, error } = await client
        .from('vw_dashboard_productos')
        .select('*');

    if(error){
        console.error(error);
        return;
    }

    const tabla = document.getElementById('tabla');

    data.forEach(p => {

        tabla.innerHTML += `
            <tr>
                <td>${p.id_producto}</td>
                <td>${p.nombre}</td>
                <td>${p.categoria}</td>
            </tr>
        `;

    });
}

cargarProductos();