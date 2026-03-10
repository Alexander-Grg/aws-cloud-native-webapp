import { getAccessToken } from '../lib/CheckAuth';

async function request(method, url, payload_data, options) {
  if (options.hasOwnProperty('setErrors')) {
    options.setErrors('');
  }
  let res;
  try {
    const headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    };

    if (options.hasOwnProperty('auth') && options.auth === true) {
      await getAccessToken();
      const access_token = localStorage.getItem("access_token");
      headers['Authorization'] = `Bearer ${access_token}`;
    }

    const attrs = {
      method: method,
      headers: headers
    };

    if (method !== 'GET') {
      attrs.body = JSON.stringify(payload_data);
    }

    res = await fetch(url, attrs);

    if (!res.ok && res.status === 500) {
      console.error("Backend threw a 500 Internal Server Error");
      if (options.hasOwnProperty('setErrors')) {
        options.setErrors(['internal_server_error']);
      }
      return;
    }

    let data = await res.json();

    if (res.status === 200 || res.status === 201) {
      options.success(data);
    } else {
      if (options.setErrors !== null) {
        options.setErrors(data);
      }
      console.log(res, data);
    }
  } catch (err) {
    console.log('request catch', err);
    if (err instanceof Response) {
      console.log('HTTP error detected:', err.status);
      if (options.hasOwnProperty('setErrors')) {
        options.setErrors([`generic_${err.status}`]);
      }
    } else {
      if (options.hasOwnProperty('setErrors')) {
        options.setErrors([`generic_500`]);
      }
    }
  }
}

export function post(url, payload_data, options) {
  request('POST', url, payload_data, options);
}

export function put(url, payload_data, options) {
  request('PUT', url, payload_data, options);
}

export function get(url, options) {
  request('GET', url, null, options);
}

export function destroy(url, payload_data, options) {
  request('DELETE', url, payload_data, options);
}